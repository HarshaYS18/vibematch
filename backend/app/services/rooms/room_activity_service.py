from __future__ import annotations

import json
from datetime import datetime
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


ROOM_ACTIVITY_ACTIONS = frozenset({"START", "UPDATE", "END"})
ROOM_ACTIVITY_KINDS = frozenset({"party", "karaoke", "social_game"})
ROOM_ACTIVITY_PHASES = frozenset({"lobby", "active", "results", "ended"})
MAX_ACTIVITY_METADATA_BYTES = 8 * 1024


def server_now_ms() -> int:
    return int(datetime.utcnow().timestamp() * 1000)


def _next_sequence(db: Session, room: Room) -> int:
    value = (
        db.query(func.max(RoomRealtimeEvent.sequence))
        .filter(RoomRealtimeEvent.room_id == room.id)
        .scalar()
    )
    return int(value or 0) + 1


def _latest_state_event(db: Session, room: Room) -> RoomRealtimeEvent | None:
    return (
        db.query(RoomRealtimeEvent)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type.like("room_activity.state.%"),
        )
        .order_by(RoomRealtimeEvent.id.desc())
        .first()
    )


def room_activity_snapshot(db: Session, room: Room) -> dict[str, Any]:
    event = _latest_state_event(db, room)
    if event is None or not isinstance(event.payload, dict):
        return {"active": False}
    return dict(event.payload)


def _safe_metadata(value: Any, *, field_name: str) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise HTTPException(status_code=400, detail=f"{field_name} must be an object")
    try:
        encoded = json.dumps(value, separators=(",", ":"), ensure_ascii=False)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail=f"{field_name} must contain JSON values only")
    if len(encoded.encode("utf-8")) > MAX_ACTIVITY_METADATA_BYTES:
        raise HTTPException(status_code=400, detail=f"{field_name} is too large")
    return dict(value)


def _record_state(
    db: Session,
    room: Room,
    actor: User | None,
    event_type: str,
    state: dict[str, Any],
    *,
    target_user_id: int | None = None,
    privacy_scope: str = "room",
) -> dict[str, Any]:
    sequence = _next_sequence(db, room)
    payload = {
        **state,
        "event_sequence": sequence,
        "updated_at_ms": server_now_ms(),
    }
    db.add(
        RoomRealtimeEvent(
            room_id=room.id,
            room_public_id=room.room_public_id,
            event_type=event_type,
            actor_user_id=actor.id if actor else None,
            target_user_id=target_user_id,
            payload=payload,
            privacy_scope=privacy_scope,
            sequence=sequence,
        )
    )
    room.updated_at = datetime.utcnow()
    db.flush()
    return payload


def _require_active(state: dict[str, Any]) -> None:
    if state.get("active") is not True or not str(state.get("session_id") or "").strip():
        raise HTTPException(status_code=409, detail="Room activity is not active")


def _validate_expected_revision(payload: dict[str, Any], state: dict[str, Any]) -> None:
    if payload.get("expected_revision") is None:
        return
    try:
        expected = int(payload["expected_revision"])
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Invalid room activity revision")
    actual = int(state.get("revision") or 0)
    if expected != actual:
        raise HTTPException(
            status_code=409,
            detail=f"Room activity revision changed from {expected} to {actual}; resync first",
        )


def _require_controller_or_admin(
    db: Session,
    room: Room,
    actor: User,
    state: dict[str, Any],
) -> None:
    if int(state.get("controller_user_id") or 0) == actor.id:
        return
    if room_permission_service.is_room_admin(db, room, actor):
        return
    raise HTTPException(status_code=403, detail="Room activity controller permission required")


def _normalize_kind(value: Any) -> str:
    kind = str(value or "").strip().lower()
    if kind not in ROOM_ACTIVITY_KINDS:
        raise HTTPException(status_code=400, detail="Unsupported room activity kind")
    return kind


def _normalize_phase(value: Any, *, fallback: str) -> str:
    phase = str(value or fallback).strip().lower()
    if phase not in ROOM_ACTIVITY_PHASES:
        raise HTTPException(status_code=400, detail="Unsupported room activity phase")
    return phase


def apply_activity_command(
    db: Session,
    room: Room,
    actor: User,
    action: str,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    command = str(action or "").strip().upper()
    if command not in ROOM_ACTIVITY_ACTIONS:
        raise HTTPException(status_code=400, detail=f"Unsupported room activity action: {command}")
    payload = dict(payload or {})
    room_permission_service.require_join(db, room, actor)

    if command == "START":
        room_permission_service.require_room_admin(db, room, actor)
        current = room_activity_snapshot(db, room)
        if current.get("active") is True:
            raise HTTPException(status_code=409, detail="End the current room activity before starting another")
        kind = _normalize_kind(payload.get("kind"))
        activity_id = str(payload.get("activity_id") or "").strip()
        if not activity_id:
            raise HTTPException(status_code=400, detail="Room activity id is required")
        title = str(payload.get("title") or activity_id).strip()[:160]
        state = {
            "active": True,
            "session_id": f"activity_{room.room_public_id}_{uuid4().hex}",
            "room_id": room.room_public_id,
            "kind": kind,
            "activity_id": activity_id[:120],
            "title": title,
            "game_id": str(payload.get("game_id") or "").strip()[:120] or None,
            "host_user_id": actor.id,
            "controller_user_id": actor.id,
            "phase": _normalize_phase(payload.get("phase"), fallback="lobby"),
            "metadata": _safe_metadata(payload.get("metadata"), field_name="metadata"),
            "post_game": {},
            "revision": 1,
        }
        return _record_state(db, room, actor, "room_activity.state.started", state)

    current = room_activity_snapshot(db, room)
    _require_active(current)
    _validate_expected_revision(payload, current)
    _require_controller_or_admin(db, room, actor, current)
    state = dict(current)
    state["revision"] = int(current.get("revision") or 0) + 1

    if command == "UPDATE":
        if payload.get("phase") is not None:
            state["phase"] = _normalize_phase(payload.get("phase"), fallback=str(current.get("phase") or "active"))
        if payload.get("title") is not None:
            title = str(payload.get("title") or "").strip()
            if title:
                state["title"] = title[:160]
        if payload.get("metadata") is not None:
            state["metadata"] = _safe_metadata(payload.get("metadata"), field_name="metadata")
        if payload.get("post_game") is not None:
            state["post_game"] = _safe_metadata(payload.get("post_game"), field_name="post_game")
        return _record_state(db, room, actor, "room_activity.state.updated", state)

    state["active"] = False
    state["phase"] = "ended"
    state["post_game"] = _safe_metadata(payload.get("post_game"), field_name="post_game")
    return _record_state(db, room, actor, "room_activity.state.ended", state)


def record_activity_invite(
    db: Session,
    room: Room,
    actor: User,
    target: User,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload = dict(payload or {})
    room_permission_service.require_join(db, room, actor)
    target_participant = (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.user_id == target.id,
            RoomParticipant.is_active.is_(True),
        )
        .first()
    )
    if target_participant is None:
        raise HTTPException(status_code=409, detail="Activity invite target must be an active room participant")

    current = room_activity_snapshot(db, room)
    _require_active(current)
    invite = {
        "invite_id": f"activity_invite_{room.room_public_id}_{uuid4().hex}",
        "room_id": room.room_public_id,
        "session_id": current.get("session_id"),
        "activity_id": current.get("activity_id"),
        "kind": current.get("kind"),
        "game_id": current.get("game_id"),
        "title": current.get("title"),
        "inviter_user_id": actor.id,
        "target_user_id": target.id,
        "revision": int(current.get("revision") or 0),
        "created_at_ms": server_now_ms(),
    }
    _record_state(
        db,
        room,
        actor,
        "room_activity.invite.sent",
        invite,
        target_user_id=target.id,
        privacy_scope="target",
    )
    return invite


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
        return (role_rank, participant.joined_at or datetime.max, int(participant.user_id))

    return min(candidates, key=rank)


def ensure_controller_after_departure(
    db: Session,
    room: Room,
    departed_user_id: int,
) -> dict[str, Any] | None:
    current = room_activity_snapshot(db, room)
    if current.get("active") is not True:
        return None
    if int(current.get("controller_user_id") or 0) != int(departed_user_id):
        return None

    state = dict(current)
    state["revision"] = int(current.get("revision") or 0) + 1
    replacement = _controller_candidate(db, room, int(departed_user_id))
    if replacement is None:
        state["active"] = False
        state["phase"] = "ended"
        state["post_game"] = {"reason": "controller_left"}
        return _record_state(db, room, None, "room_activity.state.ended", state)

    state["controller_user_id"] = int(replacement.user_id)
    return _record_state(
        db,
        room,
        None,
        "room_activity.state.controller_transferred",
        state,
        target_user_id=int(replacement.user_id),
    )
