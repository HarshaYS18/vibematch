from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomRealtimeEvent
from app.models.user import User
from app.services.rooms import room_permission_service


WATCH_PARTY_ACTIONS = {
    "LOAD",
    "PLAY",
    "PAUSE",
    "SEEK",
    "CHANGE_CONTENT",
    "SYNC",
    "END",
    "TRANSFER_CONTROL",
}


def server_now_ms() -> int:
    return int(datetime.now(timezone.utc).timestamp() * 1000)


def _next_sequence(db: Session, room: Room) -> int:
    value = (
        db.query(func.max(RoomRealtimeEvent.sequence))
        .filter(RoomRealtimeEvent.room_id == room.id)
        .scalar()
    )
    return int(value or 0) + 1


def _latest_event(db: Session, room: Room) -> RoomRealtimeEvent | None:
    return (
        db.query(RoomRealtimeEvent)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type.like("watch_party.%"),
        )
        .order_by(RoomRealtimeEvent.id.desc())
        .first()
    )


def watch_party_snapshot(db: Session, room: Room) -> dict[str, Any]:
    event = _latest_event(db, room)
    if event is None or not isinstance(event.payload, dict):
        return {"active": False}
    return dict(event.payload)


def projected_position_ms(state: dict[str, Any], at_server_time_ms: int) -> int:
    position_ms = max(0, int(state.get("position_ms") or 0))
    if state.get("active") is not True or state.get("playback_state") != "playing":
        return position_ms

    anchor_ms = int(state.get("server_anchor_time") or at_server_time_ms)
    playback_rate = float(state.get("playback_rate") or 1.0)
    elapsed_ms = max(0, at_server_time_ms - anchor_ms)
    return max(0, position_ms + round(elapsed_ms * playback_rate))


def _record_state(
    db: Session,
    room: Room,
    actor: User | None,
    event_type: str,
    state: dict[str, Any],
    *,
    target_user_id: int | None = None,
) -> dict[str, Any]:
    sequence = _next_sequence(db, room)
    payload = {**state, "event_sequence": sequence}
    db.add(
        RoomRealtimeEvent(
            room_id=room.id,
            room_public_id=room.room_public_id,
            event_type=event_type,
            actor_user_id=actor.id if actor else None,
            target_user_id=target_user_id,
            payload=payload,
            privacy_scope="room",
            sequence=sequence,
        )
    )
    room.updated_at = datetime.utcnow()
    db.flush()
    return payload


def _require_active_session(state: dict[str, Any]) -> None:
    if state.get("active") is not True or not str(state.get("session_id") or "").strip():
        raise HTTPException(status_code=409, detail="Watch Party is not active")


def _require_controller_or_admin(
    db: Session,
    room: Room,
    actor: User,
    state: dict[str, Any],
) -> None:
    controller_user_id = int(state.get("controller_user_id") or 0)
    if actor.id == controller_user_id:
        return
    if room_permission_service.is_room_admin(db, room, actor):
        return
    raise HTTPException(status_code=403, detail="Watch Party controller permission required")


def _validate_expected_revision(payload: dict[str, Any], state: dict[str, Any]) -> None:
    if payload.get("expected_revision") is None:
        return
    try:
        expected = int(payload["expected_revision"])
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Invalid Watch Party revision")
    actual = int(state.get("revision") or 0)
    if expected != actual:
        raise HTTPException(
            status_code=409,
            detail=f"Watch Party revision changed from {expected} to {actual}; resync first",
        )


def _content_fields(payload: dict[str, Any], current: dict[str, Any] | None = None) -> dict[str, Any]:
    current = current or {}
    provider = str(payload.get("provider") or current.get("provider") or "").strip().lower()
    content_id = str(payload.get("content_id") or current.get("content_id") or "").strip()
    content_url = str(payload.get("content_url") or current.get("content_url") or "").strip()
    content_title = str(payload.get("content_title") or current.get("content_title") or "").strip()
    if not provider:
        raise HTTPException(status_code=400, detail="Watch Party provider is required")
    if not content_id and not content_url:
        raise HTTPException(status_code=400, detail="Watch Party content id or URL is required")
    return {
        "provider": provider,
        "content_id": content_id or None,
        "content_url": content_url or None,
        "content_title": content_title or None,
    }


def _next_revision(state: dict[str, Any]) -> int:
    return int(state.get("revision") or 0) + 1


def _normalized_rate(value: Any, fallback: float = 1.0) -> float:
    try:
        rate = float(value)
    except (TypeError, ValueError):
        rate = fallback
    return max(0.25, min(4.0, rate))


def apply_watch_party_command(
    db: Session,
    room: Room,
    actor: User,
    action: str,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    command = str(action or "").strip().upper()
    if command not in WATCH_PARTY_ACTIONS:
        raise HTTPException(status_code=400, detail=f"Unsupported Watch Party action: {command}")

    payload = dict(payload or {})
    room_permission_service.require_join(db, room, actor)
    now_ms = server_now_ms()

    if command == "LOAD":
        room_permission_service.require_room_admin(db, room, actor)
        content = _content_fields(payload)
        state = {
            "active": True,
            "session_id": f"watch_{room.room_public_id}_{uuid4().hex}",
            "room_id": room.room_public_id,
            **content,
            "host_user_id": actor.id,
            "controller_user_id": actor.id,
            "playback_state": "paused",
            "position_ms": max(0, int(payload.get("position_ms") or 0)),
            "server_anchor_time": now_ms,
            "playback_rate": _normalized_rate(payload.get("playback_rate"), 1.0),
            "revision": 1,
        }
        return _record_state(db, room, actor, "watch_party.loaded", state)

    current = watch_party_snapshot(db, room)
    if command == "END" and current.get("active") is not True:
        return current

    _require_active_session(current)
    _validate_expected_revision(payload, current)
    _require_controller_or_admin(db, room, actor, current)

    state = dict(current)
    state["revision"] = _next_revision(current)
    state["server_anchor_time"] = now_ms

    if command == "PLAY":
        state["position_ms"] = projected_position_ms(current, now_ms)
        state["playback_state"] = "playing"
        event_type = "watch_party.played"
    elif command == "PAUSE":
        state["position_ms"] = projected_position_ms(current, now_ms)
        state["playback_state"] = "paused"
        event_type = "watch_party.paused"
    elif command == "SEEK":
        if payload.get("position_ms") is None:
            raise HTTPException(status_code=400, detail="Watch Party seek position is required")
        state["position_ms"] = max(0, int(payload["position_ms"]))
        event_type = "watch_party.seeked"
    elif command == "CHANGE_CONTENT":
        state.update(_content_fields(payload, current))
        state["position_ms"] = max(0, int(payload.get("position_ms") or 0))
        state["playback_state"] = "paused"
        state["playback_rate"] = _normalized_rate(payload.get("playback_rate"), 1.0)
        event_type = "watch_party.content_changed"
    elif command == "SYNC":
        if payload.get("position_ms") is not None:
            state["position_ms"] = max(0, int(payload["position_ms"]))
        else:
            state["position_ms"] = projected_position_ms(current, now_ms)
        requested_state = str(payload.get("playback_state") or current.get("playback_state") or "paused").strip().lower()
        if requested_state not in {"playing", "paused"}:
            raise HTTPException(status_code=400, detail="Invalid Watch Party playback state")
        state["playback_state"] = requested_state
        state["playback_rate"] = _normalized_rate(
            payload.get("playback_rate"),
            float(current.get("playback_rate") or 1.0),
        )
        event_type = "watch_party.synced"
    elif command == "TRANSFER_CONTROL":
        target_user_id = int(payload.get("target_user_id") or 0)
        target = (
            db.query(RoomParticipant)
            .filter(
                RoomParticipant.room_id == room.id,
                RoomParticipant.user_id == target_user_id,
                RoomParticipant.is_active.is_(True),
            )
            .first()
        )
        if target is None:
            raise HTTPException(status_code=409, detail="Watch Party controller must be an active room participant")
        state["position_ms"] = projected_position_ms(current, now_ms)
        state["controller_user_id"] = target_user_id
        event_type = "watch_party.control_transferred"
        return _record_state(
            db,
            room,
            actor,
            event_type,
            state,
            target_user_id=target_user_id,
        )
    elif command == "END":
        state["position_ms"] = projected_position_ms(current, now_ms)
        state["playback_state"] = "paused"
        state["active"] = False
        event_type = "watch_party.ended"
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported Watch Party action: {command}")

    return _record_state(db, room, actor, event_type, state)


def _controller_candidate(db: Session, room: Room, departed_user_id: int) -> RoomParticipant | None:
    candidates = (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.is_active.is_(True),
            RoomParticipant.user_id != departed_user_id,
        )
        .all()
    )
    if not candidates:
        return None

    def rank(participant: RoomParticipant) -> tuple[int, datetime, int]:
        if participant.user_id == room.owner_user_id:
            role_rank = 0
        elif participant.is_room_admin:
            role_rank = 1
        elif participant.is_member:
            role_rank = 2
        else:
            role_rank = 3
        return (
            role_rank,
            participant.joined_at or datetime.max,
            int(participant.user_id),
        )

    return min(candidates, key=rank)


def ensure_controller_after_departure(
    db: Session,
    room: Room,
    departed_user_id: int,
) -> dict[str, Any] | None:
    current = watch_party_snapshot(db, room)
    if current.get("active") is not True:
        return None
    if int(current.get("controller_user_id") or 0) != int(departed_user_id):
        return None

    now_ms = server_now_ms()
    state = dict(current)
    state["position_ms"] = projected_position_ms(current, now_ms)
    state["server_anchor_time"] = now_ms
    state["revision"] = _next_revision(current)
    replacement = _controller_candidate(db, room, int(departed_user_id))

    if replacement is None:
        state["active"] = False
        state["playback_state"] = "paused"
        return _record_state(db, room, None, "watch_party.ended", state)

    state["controller_user_id"] = int(replacement.user_id)
    return _record_state(
        db,
        room,
        None,
        "watch_party.control_transferred",
        state,
        target_user_id=int(replacement.user_id),
    )
