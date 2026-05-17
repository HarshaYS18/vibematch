from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomChatMessage, RoomRealtimeEvent, RoomSeatState
from app.models.user import User

_ALLOWED_SEAT_LAYOUT_IDS = {"4x2", "5x2", "4x3", "5x3", "host_4x2", "host_5x2", "host_4x3", "host_5x3"}
ROOM_STALE_PRESENCE_TIMEOUT_SECONDS = 10 * 60


def normalize_layout(layout_id: str | None) -> str:
    return layout_id if layout_id in _ALLOWED_SEAT_LAYOUT_IDS else "5x2"


def seat_count_for_layout(layout_id: str | None) -> int:
    safe_layout = normalize_layout(layout_id)
    has_host = safe_layout.startswith("host_")
    raw = safe_layout.replace("host_", "", 1)
    try:
        columns, rows = raw.split("x", 1)
        count = int(columns) * int(rows)
        return count + (2 if has_host else 0)
    except Exception:
        return 10


def get_room_by_public_id(db: Session, room_public_id: str) -> Room | None:
    return db.query(Room).filter(Room.room_public_id == room_public_id).first()


def ensure_room_seats(db: Session, room: Room) -> list[RoomSeatState]:
    max_seats = seat_count_for_layout(room.seat_layout_id)
    existing = {seat.seat_index: seat for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id).all()}
    for seat_index in range(max_seats):
        if seat_index not in existing:
            seat = RoomSeatState(room_id=room.id, seat_index=seat_index)
            db.add(seat)
            existing[seat_index] = seat
    for seat_index, seat in existing.items():
        if seat_index >= max_seats and seat.occupant_user_id is not None:
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.left_at = datetime.utcnow()
    db.flush()
    return [existing[index] for index in sorted(existing) if index < max_seats]


def room_sequence(db: Session, room: Room) -> int:
    value = db.query(func.max(RoomRealtimeEvent.sequence)).filter(RoomRealtimeEvent.room_id == room.id).scalar()
    return int(value or 0)


def _next_sequence(db: Session, room: Room) -> int:
    return room_sequence(db, room) + 1


def cleanup_stale_participants(db: Session, room: Room, now: datetime | None = None) -> list[int]:
    current_time = now or datetime.utcnow()
    cutoff = current_time - timedelta(seconds=ROOM_STALE_PRESENCE_TIMEOUT_SECONDS)
    stale_participants = (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.is_active.is_(True),
            RoomParticipant.last_seen_at.isnot(None),
            RoomParticipant.last_seen_at < cutoff,
        )
        .all()
    )
    if not stale_participants:
        return []

    stale_user_ids = [participant.user_id for participant in stale_participants]
    for participant in stale_participants:
        participant.is_active = False
        participant.left_at = current_time
        participant.last_seen_at = current_time

    seats = db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id.in_(stale_user_ids)).all()
    for seat in seats:
        released_user_id = seat.occupant_user_id
        seat.occupant_user_id = None
        seat.mic_enabled = False
        seat.admin_muted = False
        seat.left_at = current_time
        seat.updated_by_user_id = released_user_id

    for user_id in stale_user_ids:
        event = RoomRealtimeEvent(
            room_id=room.id,
            room_public_id=room.room_public_id,
            event_type="room.participant_stale_removed",
            actor_user_id=user_id,
            target_user_id=user_id,
            payload={"reason": "presence_timeout", "timeout_seconds": ROOM_STALE_PRESENCE_TIMEOUT_SECONDS},
            sequence=_next_sequence(db, room),
        )
        db.add(event)

    room.updated_at = current_time
    db.flush()
    return stale_user_ids


def active_participants(db: Session, room: Room) -> list[RoomParticipant]:
    cleanup_stale_participants(db, room)
    return (
        db.query(RoomParticipant)
        .filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True))
        .order_by(RoomParticipant.joined_at.asc())
        .all()
    )


def room_user_key(room_public_id: str, user_id: int | None) -> str | None:
    if user_id is None:
        return None
    return f"room:{room_public_id}:user:{user_id}"


def peer_id_for(room_public_id: str, user: User | None, user_id: int | None = None) -> str | None:
    resolved_user_id = user.id if user else user_id
    if resolved_user_id is None:
        return None
    public_user_id = user.public_user_id if user else resolved_user_id
    return f"{room_public_id}_user_{public_user_id}"


def user_card(user: User | None) -> dict[str, Any] | None:
    if user is None:
        return None
    return {
        "user_id": user.id,
        "backend_user_id": user.id,
        "public_user_id": user.public_user_id,
        "display_name": user.display_name or user.username or str(user.public_user_id),
        "username": user.username,
        "avatar_url": user.avatar_url,
        "official_handle": user.official_handle,
        "is_protected": bool(user.is_protected),
    }


def seat_payload(seat: RoomSeatState, room_public_id: str | None = None) -> dict[str, Any]:
    occupant = seat.occupant
    return {
        "seat_index": seat.seat_index,
        "occupant_user_id": seat.occupant_user_id,
        "occupant_backend_user_id": seat.occupant_user_id,
        "occupant_public_user_id": occupant.public_user_id if occupant else None,
        "occupant_room_user_key": room_user_key(room_public_id or "", seat.occupant_user_id) if room_public_id else None,
        "occupant_peer_id": peer_id_for(room_public_id, occupant, seat.occupant_user_id) if room_public_id else None,
        "is_locked": seat.is_locked,
        "mic_enabled": seat.mic_enabled,
        "admin_muted": seat.admin_muted,
        "locked_by_user_id": seat.locked_by_user_id,
        "admin_muted_by_user_id": seat.admin_muted_by_user_id,
        "updated_by_user_id": seat.updated_by_user_id,
        "occupant": user_card(occupant),
    }


def chat_payload(message: RoomChatMessage) -> dict[str, Any]:
    sender = message.sender
    return {
        "id": message.id,
        "room_public_id": message.room_public_id,
        "sender_user_id": message.sender_user_id,
        "sender_backend_user_id": message.sender_user_id,
        "sender_public_user_id": sender.public_user_id if sender else None,
        "sender_room_user_key": room_user_key(message.room_public_id, message.sender_user_id),
        "sender_peer_id": peer_id_for(message.room_public_id, sender, message.sender_user_id),
        "message_type": message.message_type,
        "text": message.text,
        "media_url": message.media_url,
        "metadata": message.metadata_json or {},
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "sender": user_card(sender),
    }


def recent_chat_messages(db: Session, room: Room, limit: int = 80) -> list[dict[str, Any]]:
    rows = (
        db.query(RoomChatMessage)
        .filter(RoomChatMessage.room_id == room.id, RoomChatMessage.is_deleted.is_(False))
        .order_by(RoomChatMessage.id.desc())
        .limit(limit)
        .all()
    )
    return [chat_payload(message) for message in reversed(rows)]


def room_participant_type(is_host: bool, is_room_admin: bool, is_room_member: bool) -> str:
    if is_host:
        return "owner"
    if is_room_admin:
        return "admin"
    if is_room_member:
        return "room_member"
    return "visitor"


def participant_payload(room: Room, participant: RoomParticipant, seat: RoomSeatState | None) -> dict[str, Any]:
    user = participant.user
    backend_user_id = participant.user_id
    public_user_id = user.public_user_id if user else backend_user_id
    is_host = backend_user_id == room.owner_user_id
    is_room_admin = participant.is_room_admin or is_host
    is_room_member = bool(participant.is_member or is_room_admin or is_host)
    participant_type = room_participant_type(is_host, is_room_admin, is_room_member)
    return {
        "backend_user_id": backend_user_id,
        "user_id": backend_user_id,
        "public_user_id": public_user_id,
        "room_user_key": room_user_key(room.room_public_id, backend_user_id),
        "peer_id": peer_id_for(room.room_public_id, user, backend_user_id),
        "display_name": (user.display_name or user.username or str(public_user_id)) if user else "Vibe User",
        "username": user.username if user else None,
        "avatar_url": user.avatar_url if user else None,
        "official_handle": user.official_handle if user else None,
        "is_protected": bool(user.is_protected) if user else False,
        "is_host": is_host,
        "is_room_owner": is_host,
        "is_room_admin": is_room_admin,
        "is_room_member": is_room_member,
        "participant_type": participant_type,
        "role_label": "Host" if is_host else ("Admin" if is_room_admin else ("Room Member" if is_room_member else "Visitor")),
        "seat_index": seat.seat_index if seat else None,
        "mic_enabled": seat.mic_enabled if seat else False,
        "admin_muted": seat.admin_muted if seat else False,
        "is_active": participant.is_active,
        "is_member": is_room_member,
        "joined_at": participant.joined_at.isoformat() if participant.joined_at else None,
        "last_seen_at": participant.last_seen_at.isoformat() if participant.last_seen_at else None,
    }


def room_snapshot(db: Session, room: Room, include_chat: bool = True) -> dict[str, Any]:
    seats = ensure_room_seats(db, room)
    participants = active_participants(db, room)
    seats = ensure_room_seats(db, room)
    active_count = len(participants)
    if room.online_count != active_count:
        room.online_count = active_count
        db.flush()

    canonical_participants = []
    peers = []
    seen_backend_user_ids: set[int] = set()
    for participant in participants:
        if participant.user_id in seen_backend_user_ids:
            continue
        seen_backend_user_ids.add(participant.user_id)
        seat = next((item for item in seats if item.occupant_user_id == participant.user_id), None)
        participant_data = participant_payload(room, participant, seat)
        canonical_participants.append(participant_data)
        peers.append({
            "peer_id": participant_data["peer_id"],
            "user_id": str(participant_data["backend_user_id"]),
            "backend_user_id": participant_data["backend_user_id"],
            "public_user_id": participant_data["public_user_id"],
            "room_user_key": participant_data["room_user_key"],
            "display_name": participant_data["display_name"],
            "avatar_url": participant_data["avatar_url"],
            "is_host": participant_data["is_host"],
            "is_room_owner": participant_data["is_room_owner"],
            "is_room_admin": participant_data["is_room_admin"],
            "is_room_member": participant_data["is_room_member"],
            "participant_type": participant_data["participant_type"],
            "role_label": participant_data["role_label"],
            "seat_index": participant_data["seat_index"],
            "mic_enabled": participant_data["mic_enabled"],
            "admin_muted": participant_data["admin_muted"],
        })

    payload: dict[str, Any] = {
        "room_id": room.room_public_id,
        "room_public_id": room.room_public_id,
        "database_room_id": room.id,
        "owner_user_id": room.owner_user_id,
        "name": room.name,
        "subtitle": room.subtitle,
        "avatar_url": room.avatar_url,
        "cover_photo_url": room.cover_photo_url,
        "language": room.language,
        "mode": room.mode,
        "room_type": room.room_type,
        "online_count": len(canonical_participants),
        "is_active": room.is_active,
        "is_secret": room.is_secret,
        "is_locked": room.is_locked,
        "is_members_only": room.is_members_only,
        "allow_screenshots": room.allow_screenshots,
        "background_theme_id": room.background_theme_id,
        "seat_layout_id": normalize_layout(room.seat_layout_id),
        "seat_count": seat_count_for_layout(room.seat_layout_id),
        "announcement_text": room.announcement_text,
        "state_version": room_sequence(db, room),
        "updated_at": room.updated_at.isoformat() if room.updated_at else None,
        "seats": [seat_payload(seat, room.room_public_id) for seat in seats],
        "locked_seat_indexes": [seat.seat_index for seat in seats if seat.is_locked],
        "participants": canonical_participants,
        "peers": peers,
        "peer_count": len(canonical_participants),
    }
    if include_chat:
        payload["recent_messages"] = recent_chat_messages(db, room)
    return payload