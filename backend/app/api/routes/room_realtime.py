import json
import re
from datetime import datetime, timedelta
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from starlette.websockets import WebSocketState

from app.database import SessionLocal, get_db
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.services.rooms import room_action_service, room_state_service

router = APIRouter(tags=["Room Realtime"])


@router.get("/rooms/{room_public_id}/realtime-snapshot")
def get_room_realtime_snapshot(room_public_id: str, db: Session = Depends(get_db)):
    room = room_state_service.get_room_by_public_id(db, room_public_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    snapshot = room_state_service.room_snapshot(db, room)
    db.commit()
    return {"room_id": room_public_id, "room": snapshot}


def _websocket_connected(websocket: WebSocket) -> bool:
    return websocket.client_state == WebSocketState.CONNECTED and websocket.application_state == WebSocketState.CONNECTED


def _first_identity_value(payload: dict[str, Any], keys: tuple[str, ...]) -> str | None:
    for key in keys:
        raw = payload.get(key)
        if raw is None:
            continue
        value = str(raw).strip()
        if value:
            return value
    return None


def _numeric_identity_candidates(raw: str | None) -> list[int]:
    if raw is None:
        return []
    value = str(raw).strip()
    if not value:
        return []
    candidates: list[int] = []
    if value.isdigit():
        candidates.append(int(value))
    for match in re.findall(r"(?:^|_)user_(\d+)$", value):
        candidates.append(int(match))
    seen: set[int] = set()
    unique: list[int] = []
    for item in candidates:
        if item in seen:
            continue
        seen.add(item)
        unique.append(item)
    return unique


def _resolve_user_from_value(db: Session, raw: str | int | None) -> User | None:
    candidates = _numeric_identity_candidates(str(raw) if raw is not None else None)
    for candidate in candidates:
        user = db.query(User).filter(User.id == candidate).first()
        if user is not None:
            return user
        user = db.query(User).filter(User.public_user_id == candidate).first()
        if user is not None:
            return user
        user = db.query(User).filter(User.display_custom_id == candidate).first()
        if user is not None:
            return user
    return None


def _payload_user_id(payload: dict[str, Any]) -> int | None:
    raw = _first_identity_value(payload, ("backend_user_id", "actor_user_id", "user_id", "public_user_id", "peer_id"))
    candidates = _numeric_identity_candidates(raw)
    return candidates[0] if candidates else None


def _target_user(db: Session, payload: dict[str, Any], fallback: int | None = None) -> User | None:
    raw = _first_identity_value(payload, ("target_backend_user_id", "target_user_id", "target_public_user_id", "target_peer_id"))
    user = _resolve_user_from_value(db, raw)
    if user is not None:
        return user
    return db.query(User).filter(User.id == fallback).first() if fallback else None


def _int_payload(payload: dict[str, Any], key: str, default: int = -1) -> int:
    try:
        return int(payload.get(key) if payload.get(key) is not None else default)
    except (TypeError, ValueError):
        return default


def _bool_payload(payload: dict[str, Any], key: str, default: bool = False) -> bool:
    raw = payload.get(key)
    if raw is None:
        return default
    if isinstance(raw, bool):
        return raw
    return str(raw).strip().lower() in {"true", "1", "yes", "on"}


def _room_peer_id(room_id: str, user: User | None) -> str:
    if user is None:
        return ""
    return f"{room_id}_user_{user.public_user_id}"


def _room_user_key(user: User | None) -> str:
    if user is None:
        return ""
    return f"user_{user.public_user_id}"


def _display_name(user: User | None, fallback: str = "Vibe User") -> str:
    if user is None:
        return fallback
    return user.display_name or user.username or str(user.public_user_id)


def _user_identity_payload(room_id: str, prefix: str, user: User | None) -> dict[str, Any]:
    if user is None:
        return {}
    return {
        f"{prefix}_user_id": _room_user_key(user),
        f"{prefix}_backend_user_id": user.id,
        f"{prefix}_public_user_id": user.public_user_id,
        f"{prefix}_peer_id": _room_peer_id(room_id, user),
        f"{prefix}_name": _display_name(user),
        f"{prefix}_avatar_url": user.avatar_url,
    }


def _event_payload(event_type: str, room_id: str, room: dict[str, Any], extra: dict[str, Any] | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {"room_id": room_id, "room": room}
    if extra:
        payload.update(extra)
    return {"type": event_type, "payload": payload}


def _chat_event_payload(room_id: str, user: User, text: str, message_id: int | None = None) -> dict[str, Any]:
    created_at = datetime.utcnow().isoformat()
    event_id = f"chat_{message_id}" if message_id else f"chat_{room_id}_{user.id}_{uuid4().hex}"
    return {"type": "room/system_event", "payload": {"id": event_id, "event_type": "room_chat_message", "type": "room_chat_message", "room_id": room_id, "actor_user_id": str(user.id), "actor_public_user_id": user.public_user_id, "actor_name": _display_name(user, f"User {user.public_user_id}"), "actor_avatar_url": user.avatar_url, "actor_vip_level": 0, "actor_sending_level": 0, "actor_receiving_level": 0, "target_user_id": "", "target_name": "", "message": text, "created_at": created_at}}


def _system_event_payload(
    room_id: str,
    event_type: str,
    message: str,
    *,
    actor: User | None = None,
    target: User | None = None,
    seat_index: int | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "id": f"{event_type}_{room_id}_{uuid4().hex}",
        "event_type": event_type,
        "type": event_type,
        "room_id": room_id,
        "actor_user_id": _room_user_key(actor) if actor else "",
        "actor_backend_user_id": actor.id if actor else None,
        "actor_public_user_id": actor.public_user_id if actor else None,
        "actor_name": _display_name(actor, "System"),
        "actor_avatar_url": actor.avatar_url if actor else None,
        "target_user_id": _room_user_key(target) if target else "",
        "target_backend_user_id": target.id if target else None,
        "target_public_user_id": target.public_user_id if target else None,
        "target_name": _display_name(target, "") if target else "",
        "message": message,
        "created_at": datetime.utcnow().isoformat(),
        "auto_dismiss_seconds": 10,
    }
    if seat_index is not None:
        payload["seat_index"] = seat_index
    return {"type": "room/system_event", "payload": payload}


def _setting_message(actor: User, setting_name: str, enabled: bool) -> str:
    return f"{_display_name(actor, 'Room admin')} turned {setting_name} {'on' if enabled else 'off'}"


def _latest_chat_message_matches(snapshot: dict[str, Any], user: User, text: str) -> tuple[bool, int | None]:
    recent_messages = snapshot.get("recent_messages") or []
    if not recent_messages:
        return False, None
    latest = recent_messages[-1]
    if not isinstance(latest, dict):
        return False, None
    if str(latest.get("text") or "").strip() != text.strip():
        return False, None
    sender_id = latest.get("sender_backend_user_id") or latest.get("sender_user_id")
    if str(sender_id) != str(user.id):
        return False, None
    try:
        return True, int(latest.get("id"))
    except Exception:
        return True, None


def _snapshot_has_user_on_seat(snapshot: dict[str, Any], user: User, seat_index: int) -> bool:
    aliases = {str(user.id), str(user.public_user_id), _room_user_key(user)}
    for peer in snapshot.get("peers") or []:
        if not isinstance(peer, dict):
            continue
        try:
            if int(peer.get("seat_index")) != seat_index:
                continue
        except Exception:
            continue
        values = {
            str(peer.get("backend_user_id") or ""),
            str(peer.get("user_id") or ""),
            str(peer.get("public_user_id") or ""),
        }
        if aliases.intersection(values):
            return True
    return False


def _snapshot_user_is_stealth(snapshot: dict[str, Any], user: User | None) -> bool:
    if user is None:
        return False
    participants = snapshot.get("internal_participants") or []
    if not isinstance(participants, list):
        return False
    return any(
        isinstance(item, dict)
        and int(item.get("backend_user_id") or 0) == user.id
        and item.get("is_stealth") is True
        for item in participants
    )


async def _broadcast_snapshot(room_id: str, event_type: str, room: dict[str, Any], extra: dict[str, Any] | None = None) -> None:
    await room_realtime_connections.broadcast_room(room_id, _event_payload(event_type, room_id, room, extra))


def _resolve_user(db: Session, payload: dict[str, Any], fallback_user_id: int | None = None) -> User | None:
    raw = _first_identity_value(payload, ("backend_user_id", "actor_user_id", "user_id", "public_user_id", "peer_id"))
    user = _resolve_user_from_value(db, raw)
    if user is not None:
        return user
    return db.query(User).filter(User.id == fallback_user_id).first() if fallback_user_id else None


@router.websocket("/ws/room-realtime")
async def room_realtime_socket(websocket: WebSocket) -> None:
    active_room_id: str | None = None
    active_user_id: int | None = None
    await websocket.accept()
    try:
        while _websocket_connected(websocket):
            try:
                raw = await websocket.receive_text()
            except WebSocketDisconnect:
                break
            except RuntimeError:
                break
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                continue
            event_type = str(message.get("type") or "unknown")
            payload = message.get("payload") if isinstance(message.get("payload"), dict) else {}
            room_id = str(payload.get("room_id") or active_room_id or "").strip()
            if not room_id:
                continue
            with SessionLocal() as db:
                room = room_state_service.get_room_by_public_id(db, room_id)
                if room is None:
                    await room_realtime_connections.send_json(websocket, {"type": "error", "payload": {"room_id": room_id, "message": "Room not found"}})
                    continue
                user = _resolve_user(db, payload, active_user_id)
                if active_room_id is None:
                    active_room_id = room_id
                    active_user_id = user.id if user else _payload_user_id(payload)
                    await room_realtime_connections.connect_room(room_id, websocket, active_user_id)
                if user is not None:
                    active_user_id = user.id

                if event_type == "room/snapshot":
                    snapshot = room_state_service.room_snapshot(db, room)
                    db.commit()
                    await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                    continue

                if event_type == "room/join":
                    try:
                        snapshot = room_action_service.join_room(db, room, user, payload) if user is not None else room_state_service.room_snapshot(db, room)
                        db.commit()
                    except HTTPException as exc:
                        db.rollback()
                        await room_realtime_connections.send_json(
                            websocket,
                            {
                                "type": "room/join_blocked",
                                "payload": {
                                    "room_id": room_id,
                                    "reason": str(exc.detail),
                                    "status_code": exc.status_code,
                                },
                            },
                        )
                        continue
                    if not _snapshot_user_is_stealth(snapshot, user):
                        await _broadcast_snapshot(room_id, "room/joined", snapshot)
                        if user is not None:
                            await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "user_entered", f"{_display_name(user)} entered the room", actor=user, target=user))
                    await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                    continue

                if event_type == "room/leave":
                    snapshot = room_action_service.leave_room(db, room, user, release_seat=payload.get("release_seat") is True) if user is not None else room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room/peer_left", snapshot)
                    continue

                if event_type == "room/heartbeat":
                    try:
                        snapshot = room_action_service.heartbeat_room(db, room, user) if user is not None else room_state_service.room_snapshot(db, room, include_chat=False)
                        db.commit()
                    except HTTPException as exc:
                        db.rollback()
                        await room_realtime_connections.send_json(
                            websocket,
                            {
                                "type": "room/join_blocked",
                                "payload": {
                                    "room_id": room_id,
                                    "reason": str(exc.detail),
                                    "status_code": exc.status_code,
                                },
                            },
                        )
                        continue
                    await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                    continue

                if event_type == "room_member/request" and user is not None:
                    snapshot = room_action_service.request_room_membership(db, room, user)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_member/request_updated", snapshot, {"request_user_id": user.id})
                    continue

                if event_type == "room_member/approve" and user is not None:
                    target = _target_user(db, payload)
                    snapshot = room_action_service.approve_room_membership(db, room, user, target) if target else room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_member/request_updated", snapshot, {"target_user_id": target.id if target else None, "decision": "approved"})
                    continue

                if event_type == "room_member/reject" and user is not None:
                    target = _target_user(db, payload)
                    snapshot = room_action_service.reject_room_membership(db, room, user, target) if target else room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_member/request_updated", snapshot, {"target_user_id": target.id if target else None, "decision": "rejected"})
                    continue

                if event_type == "room_member/remove" and user is not None:
                    target = _target_user(db, payload)
                    snapshot = room_action_service.remove_room_member(db, room, user, target) if target else room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_member/request_updated", snapshot, {"target_user_id": target.id if target else None, "decision": "removed"})
                    continue

                if event_type == "seat/take" and user is not None:
                    snapshot = room_action_service.take_or_request_seat(db, room, user, _int_payload(payload, "seat_index"))
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "seat/leave" and user is not None:
                    snapshot = room_action_service.leave_seat(db, room, user)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "seat_invite/send" and user is not None:
                    target = _target_user(db, payload)
                    seat_index = _int_payload(payload, "seat_index")
                    previous_invite_id = room_action_service.latest_seat_invite_id(db, room, user, target, seat_index) if target else None
                    snapshot = room_action_service.send_seat_invite(db, room, user, target, seat_index) if target else room_state_service.room_snapshot(db, room)
                    next_invite_id = room_action_service.latest_seat_invite_id(db, room, user, target, seat_index) if target else None
                    db.commit()
                    if target is not None and next_invite_id == previous_invite_id:
                        await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                        continue
                    invite_id = f"seat_invite_{room_id}_{user.id}_{target.id if target else 'none'}_{seat_index}_{uuid4().hex}"
                    if target is not None:
                        invite_payload = {
                            "id": invite_id,
                            "invite_id": invite_id,
                            "room_id": room_id,
                            "seat_index": seat_index,
                            "room": snapshot,
                            **_user_identity_payload(room_id, "inviter", user),
                            **_user_identity_payload(room_id, "target", target),
                        }
                        await room_realtime_connections.send_room_user(room_id, target.id, {"type": "seat_invite/received", "payload": invite_payload})
                        invite_message = f"{_display_name(user, 'Room admin')} invited {_display_name(target, 'you')} to seat {seat_index + 1}"
                        await room_realtime_connections.send_room_user(room_id, user.id, _system_event_payload(room_id, "seat_invite_sent", invite_message, actor=user, target=target, seat_index=seat_index))
                        await room_realtime_connections.send_room_user(room_id, target.id, _system_event_payload(room_id, "seat_invite_sent", invite_message, actor=user, target=target, seat_index=seat_index))
                    await _broadcast_snapshot(room_id, "seat_invite/sent", snapshot, {"target_user_id": target.id if target else None, "seat_index": seat_index})
                    continue

                if event_type == "seat_invite/accept" and user is not None:
                    seat_index = _int_payload(payload, "seat_index")
                    snapshot = room_action_service.accept_seat_invite(db, room, user, seat_index)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    await _broadcast_snapshot(room_id, "seat_invite/accepted", snapshot, {"target_user_id": user.id, "seat_index": seat_index})
                    continue

                if event_type == "seat_invite/reject" and user is not None:
                    seat_index = _int_payload(payload, "seat_index")
                    snapshot = room_action_service.reject_seat_invite(db, room, user, seat_index)
                    db.commit()
                    await room_realtime_connections.send_room_user(
                        room_id,
                        user.id,
                        _event_payload("seat_invite/rejected", room_id, snapshot, {"seat_index": seat_index}),
                    )
                    continue

                if event_type == "seat_application/request" and user is not None:
                    seat_index = _int_payload(payload, "seat_index")
                    if not room.apply_only_mode_enabled:
                        snapshot = room_action_service.take_seat(db, room, user, seat_index)
                        db.commit()
                        await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                        continue
                    previous_request_id = room_action_service.latest_seat_application_request_id(db, room, user)
                    snapshot = room_action_service.request_seat_application(db, room, user, seat_index)
                    next_request_id = room_action_service.latest_seat_application_request_id(db, room, user)
                    db.commit()
                    if next_request_id == previous_request_id:
                        await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                        continue
                    now = datetime.utcnow()
                    application_payload = {
                        "id": f"seat_application_{room_id}_{user.id}_{seat_index}_{uuid4().hex}",
                        "room_id": room_id,
                        "seat_index": seat_index,
                        "created_at": now.isoformat(),
                        "expires_at": (now + timedelta(seconds=20)).isoformat(),
                        "room": snapshot,
                        **_user_identity_payload(room_id, "applicant", user),
                    }
                    await room_realtime_connections.broadcast_room(room_id, {"type": "seat_application/received", "payload": application_payload})
                    await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "seat_application_requested", f"{_display_name(user, 'A user')} applied for seat {seat_index + 1}", actor=user, target=user, seat_index=seat_index))
                    await _broadcast_snapshot(room_id, "seat_application/requested", snapshot, {"applicant_user_id": user.id, "seat_index": seat_index})
                    continue

                if event_type == "seat_application/reject" and user is not None:
                    target = _target_user(db, payload)
                    seat_index = _int_payload(payload, "seat_index")
                    snapshot = room_action_service.reject_seat_application(db, room, user, target, seat_index) if target else room_state_service.room_snapshot(db, room)
                    db.commit()
                    if target is not None:
                        await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "seat_application_rejected", f"{_display_name(target)}'s request for seat {seat_index + 1} was rejected", actor=user, target=target, seat_index=seat_index))
                    await _broadcast_snapshot(room_id, "seat_application/rejected", snapshot, {"target_user_id": target.id if target else None, "seat_index": seat_index})
                    continue

                if event_type == "admin/seat_assign" and user is not None:
                    target = _target_user(db, payload)
                    seat_index = _int_payload(payload, "seat_index")
                    snapshot = room_action_service.assign_seat(db, room, user, target, seat_index) if target else room_state_service.room_snapshot(db, room)
                    db.commit()
                    if target is not None and _snapshot_has_user_on_seat(snapshot, target, seat_index):
                        await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "seat_application_agreed", f"{_display_name(target)}'s request for seat {seat_index + 1} was agreed", actor=user, target=target, seat_index=seat_index))
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type in {"admin/seat_leave", "admin/seat_leave_lock"}:
                    target = _target_user(db, payload)
                    snapshot = room_action_service.leave_seat(db, room, target, actor_user_id=active_user_id) if target else room_state_service.room_snapshot(db, room)
                    if event_type == "admin/seat_leave_lock":
                        snapshot = room_action_service.lock_seat(db, room, _int_payload(payload, "seat_index"), True, actor_user_id=active_user_id)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "admin/seat_lock":
                    snapshot = room_action_service.lock_seat(db, room, _int_payload(payload, "seat_index"), True, actor_user_id=active_user_id)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "admin/seat_unlock":
                    snapshot = room_action_service.lock_seat(db, room, _int_payload(payload, "seat_index"), False, actor_user_id=active_user_id)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "admin/kick" and user is not None:
                    target = _target_user(db, payload)
                    reason = str(payload.get("reason") or "Removed by room admin")
                    duration = str(payload.get("duration") or "1h")
                    snapshot = room_action_service.kick_user(db, room, user, target, reason=reason, duration=duration) if target else room_state_service.room_snapshot(db, room)
                    db.commit()
                    if target is not None:
                        await room_realtime_connections.send_room_user(room_id, target.id, {"type": "room/kicked", "payload": {"room_id": room_id, "room": snapshot, "reason": reason, "duration": duration, **_user_identity_payload(room_id, "target", target)}})
                        await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "user_removed", f"{_display_name(target)} was removed from the room", actor=user, target=target))
                    await _broadcast_snapshot(room_id, "room/peer_left", snapshot, {"target_user_id": target.id if target else None})
                    continue

                if event_type == "admin/kick_remove":
                    snapshot = room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "kick_block/remove_result", snapshot, {"removed": True, "target_user_id": payload.get("target_user_id")})
                    continue

                if event_type == "mic/set_enabled" and user is not None:
                    snapshot = room_action_service.set_mic_enabled(db, room, user, payload.get("enabled") is True)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "admin_mute/set":
                    target = _target_user(db, payload)
                    snapshot = room_action_service.set_admin_mute(db, room, target.id, payload.get("muted") is True, actor_user_id=active_user_id) if target else room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "admin_mute/updated", snapshot, {"target_user_id": target.id if target else None, "admin_muted": payload.get("muted") is True})
                    continue

                if event_type == "room_settings/seat_layout":
                    snapshot = room_action_service.set_seat_layout(db, room, str(payload.get("seat_layout_id") or "5x2"), actor_user_id=active_user_id)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"seat_layout_id": snapshot.get("seat_layout_id")})
                    continue

                if event_type == "room_settings/background_theme":
                    snapshot = room_action_service.set_background_theme(db, room, str(payload.get("background_theme_id") or "default"), actor_user_id=active_user_id)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"background_theme_id": snapshot.get("background_theme_id")})
                    continue

                if event_type == "room_settings/privacy" and user is not None:
                    snapshot = room_action_service.set_room_privacy(db, room, user, str(payload.get("mode") or payload.get("privacy_mode") or "Open"))
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"mode": snapshot.get("mode")})
                    continue

                if event_type == "room_settings/screenshots" and user is not None:
                    snapshot = room_action_service.set_room_screenshots(db, room, user, _bool_payload(payload, "allow_screenshots", True))
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"allow_screenshots": snapshot.get("allow_screenshots")})
                    continue

                if event_type == "room_settings/images" and user is not None:
                    enabled = _bool_payload(payload, "room_images_enabled", _bool_payload(payload, "enabled", True))
                    snapshot = room_action_service.set_room_images_enabled(db, room, user, enabled)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"room_images_enabled": snapshot.get("room_images_enabled")})
                    await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "room_system_message", _setting_message(user, "image messages", enabled), actor=user))
                    continue

                if event_type == "room_settings/guest_messages" and user is not None:
                    enabled = _bool_payload(payload, "guest_messages_enabled", _bool_payload(payload, "enabled", True))
                    snapshot = room_action_service.set_guest_messages_enabled(db, room, user, enabled)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"guest_messages_enabled": snapshot.get("guest_messages_enabled")})
                    await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "room_system_message", _setting_message(user, "guest messages", enabled), actor=user))
                    continue

                if event_type == "room_settings/apply_mode" and user is not None:
                    enabled = _bool_payload(payload, "apply_only_mode_enabled", _bool_payload(payload, "enabled", False))
                    snapshot = room_action_service.set_apply_only_mode_enabled(db, room, user, enabled)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"apply_only_mode_enabled": snapshot.get("apply_only_mode_enabled")})
                    await room_realtime_connections.broadcast_room(room_id, _system_event_payload(room_id, "room_system_message", _setting_message(user, "apply-only seat mode", enabled), actor=user))
                    continue

                if event_type == "room_settings/announcement" and user is not None:
                    snapshot = room_action_service.set_announcement(db, room, user, str(payload.get("announcement_text") or ""))
                    db.commit()
                    await _broadcast_snapshot(room_id, "room_settings/updated", snapshot, {"announcement_text": snapshot.get("announcement_text")})
                    continue

                if event_type in {"room_chat/send", "room/chat"}:
                    text = str(payload.get("text") or "").strip()
                    if text and user is not None:
                        snapshot = room_action_service.create_chat_message(db, room, user, text, message_type=str(payload.get("message_type") or "text"), metadata=payload)
                        should_broadcast_chat, message_id = _latest_chat_message_matches(snapshot, user, text)
                        db.commit()
                        if should_broadcast_chat:
                            await room_realtime_connections.broadcast_room(room_id, _chat_event_payload(room_id, user, text, message_id=message_id))
                    else:
                        snapshot = room_state_service.room_snapshot(db, room)
                        db.commit()
                    await _broadcast_snapshot(room_id, "room.chat.message_created", snapshot)
                    continue

                snapshot = room_state_service.room_snapshot(db, room)
                db.commit()
                await _broadcast_snapshot(room_id, event_type, snapshot, payload)
    except WebSocketDisconnect:
        pass
    except RuntimeError:
        pass
    finally:
        room_realtime_connections.disconnect(websocket)
