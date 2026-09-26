from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy.orm import Session

from app.core.redis_client import get_realtime_redis
from app.models.room import Room
from app.models.room_participant import RoomParticipant


_GLOBAL_USER_LEASE_PREFIX = "funkey:realtime:gateway:user-active"
_USER_ROOM_LEASE_PREFIX = "funkey:realtime:gateway:user-rooms"
_ROOM_USER_LEASE_PREFIX = "funkey:realtime:gateway:room-users"


@dataclass(frozen=True)
class RealtimePresenceProjection:
    is_online: bool
    room: Room | None = None
    room_entered_at: datetime | None = None


def _user_lease_key(user_id: int) -> str:
    return f"{_GLOBAL_USER_LEASE_PREFIX}:{int(user_id)}"


def _user_room_key(user_id: int) -> str:
    return f"{_USER_ROOM_LEASE_PREFIX}:{int(user_id)}"


def _room_user_key(room_public_id: str) -> str:
    return f"{_ROOM_USER_LEASE_PREFIX}:{room_public_id.strip()}"


def _text(value: object) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def active_room_ids_for_user(user_id: int) -> set[str]:
    """Return rooms with a live Go-gateway lease for this user."""
    redis_client = get_realtime_redis()
    try:
        values = redis_client.zrangebyscore(
            _user_room_key(user_id),
            time.time(),
            "+inf",
        )
    except Exception:
        return set()
    return {_text(value) for value in values if _text(value).strip()}


def room_online_user_ids(room_public_id: str) -> set[int]:
    """Return backend user IDs with an unexpired socket lease in a room."""
    redis_client = get_realtime_redis()
    try:
        values = redis_client.zrangebyscore(
            _room_user_key(room_public_id),
            time.time(),
            "+inf",
        )
    except Exception:
        return set()
    result: set[int] = set()
    for value in values:
        try:
            user_id = int(_text(value))
        except (TypeError, ValueError):
            continue
        if user_id > 0:
            result.add(user_id)
    return result


def room_online_user_ids_batch(
    room_public_ids: list[str] | tuple[str, ...] | set[str],
) -> dict[str, set[int]]:
    """Batch live room user IDs from the Go gateway lease projection."""
    resolved = [room_id.strip() for room_id in dict.fromkeys(room_public_ids) if room_id.strip()]
    if not resolved:
        return {}
    redis_client = get_realtime_redis()
    now = time.time()
    try:
        pipe = redis_client.pipeline(transaction=False)
        for room_id in resolved:
            pipe.zrangebyscore(_room_user_key(room_id), now, "+inf")
        values_by_room = pipe.execute()
    except Exception:
        return {room_id: set() for room_id in resolved}

    result: dict[str, set[int]] = {}
    for room_id, values in zip(resolved, values_by_room, strict=False):
        user_ids: set[int] = set()
        for value in values or []:
            try:
                user_id = int(_text(value))
            except (TypeError, ValueError):
                continue
            if user_id > 0:
                user_ids.add(user_id)
        result[room_id] = user_ids
    return result


def room_online_counts(room_public_ids: list[str] | tuple[str, ...] | set[str]) -> dict[str, int]:
    """Batch Redis room counts without consulting participant heartbeat timestamps."""
    resolved = [room_id.strip() for room_id in dict.fromkeys(room_public_ids) if room_id.strip()]
    if not resolved:
        return {}
    redis_client = get_realtime_redis()
    now = time.time()
    try:
        pipe = redis_client.pipeline(transaction=False)
        for room_id in resolved:
            pipe.zcount(_room_user_key(room_id), now, "+inf")
        values = pipe.execute()
    except Exception:
        return {room_id: 0 for room_id in resolved}
    return {
        room_id: int(value or 0)
        for room_id, value in zip(resolved, values, strict=False)
    }


def project_user_presence(
    db: Session,
    user_ids: list[int] | tuple[int, ...] | set[int],
) -> dict[int, RealtimePresenceProjection]:
    """Project online/room presence from the Go gateway Redis leases.

    PostgreSQL supplies only durable room metadata and the participant's original
    join timestamp. It is never used to decide whether a user is online.
    Redis failure is fail-closed: callers render the user offline rather than
    reviving the retired database-heartbeat authority.
    """
    resolved_ids = [int(user_id) for user_id in dict.fromkeys(user_ids) if int(user_id) > 0]
    if not resolved_ids:
        return {}

    now = time.time()
    redis_client = get_realtime_redis()
    try:
        pipe = redis_client.pipeline(transaction=False)
        for user_id in resolved_ids:
            pipe.zcount(_user_lease_key(user_id), now, "+inf")
        online_counts = pipe.execute()
    except Exception:
        return {
            user_id: RealtimePresenceProjection(is_online=False)
            for user_id in resolved_ids
        }

    online_by_user = {
        user_id: int(count or 0) > 0
        for user_id, count in zip(resolved_ids, online_counts, strict=False)
    }
    online_ids = [user_id for user_id in resolved_ids if online_by_user[user_id]]
    room_by_user: dict[int, str] = {}

    if online_ids:
        try:
            pipe = redis_client.pipeline(transaction=False)
            for user_id in online_ids:
                pipe.zrevrangebyscore(
                    _user_room_key(user_id),
                    "+inf",
                    now,
                    start=0,
                    num=1,
                )
            room_results = pipe.execute()
            for user_id, values in zip(online_ids, room_results, strict=False):
                if values:
                    room_by_user[user_id] = _text(values[0])
        except Exception:
            room_by_user = {}

    room_ids = set(room_by_user.values())
    rooms_by_public_id: dict[str, Room] = {}
    if room_ids:
        rooms = (
            db.query(Room)
            .filter(Room.room_public_id.in_(room_ids), Room.is_active.is_(True))
            .all()
        )
        rooms_by_public_id = {room.room_public_id: room for room in rooms}

    entered_at: dict[tuple[int, int], datetime] = {}
    active_memberships: set[tuple[int, int]] = set()
    room_db_ids = {room.id for room in rooms_by_public_id.values()}
    if room_db_ids and room_by_user:
        participants = (
            db.query(RoomParticipant)
            .filter(
                RoomParticipant.user_id.in_(room_by_user.keys()),
                RoomParticipant.room_id.in_(room_db_ids),
                RoomParticipant.is_active.is_(True),
            )
            .all()
        )
        active_memberships = {
            (participant.user_id, participant.room_id)
            for participant in participants
        }
        entered_at = {
            (participant.user_id, participant.room_id): participant.joined_at
            for participant in participants
        }

    result: dict[int, RealtimePresenceProjection] = {}
    for user_id in resolved_ids:
        if not online_by_user[user_id]:
            result[user_id] = RealtimePresenceProjection(is_online=False)
            continue
        room = rooms_by_public_id.get(room_by_user.get(user_id, ""))
        if room is not None and (user_id, room.id) not in active_memberships:
            # Socket leases decide whether the user is online. Durable Room
            # Control membership decides whether a room may be disclosed.
            room = None
        result[user_id] = RealtimePresenceProjection(
            is_online=True,
            room=room,
            room_entered_at=entered_at.get((user_id, room.id)) if room else None,
        )
    return result


def is_user_online(user_id: int) -> bool:
    redis_client = get_realtime_redis()
    try:
        return int(
            redis_client.zcount(_user_lease_key(user_id), time.time(), "+inf") or 0
        ) > 0
    except Exception:
        return False
