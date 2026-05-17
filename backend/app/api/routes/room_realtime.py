import json
from typing import Any

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


def _payload_user_id(payload: dict[str, Any]) -> int | None:
    raw = payload.get("user_id") or payload.get("backend_user_id") or payload.get("actor_user_id")
    try:
        return int(str(raw)) if raw is not None and str(raw).strip() else None
    except ValueError:
        return None


def _target_user_id(payload: dict[str, Any], fallback: int | None = None) -> int | None:
    raw = payload.get("target_user_id") or payload.get("user_id") or fallback
    try:
        return int(str(raw)) if raw is not None and str(raw).strip() else None
    except ValueError:
        return fallback


def _int_payload(payload: dict[str, Any], key: str, default: int = -1) -> int:
    try:
        return int(payload.get(key) if payload.get(key) is not None else default)
    except (TypeError, ValueError):
        return default


def _event_payload(event_type: str, room_id: str, room: dict[str, Any], extra: dict[str, Any] | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {"room_id": room_id, "room": room}
    if extra:
        payload.update(extra)
    return {"type": event_type, "payload": payload}


async def _broadcast_snapshot(room_id: str, event_type: str, room: dict[str, Any], extra: dict[str, Any] | None = None) -> None:
    await room_realtime_connections.broadcast_room(room_id, _event_payload(event_type, room_id, room, extra))


def _resolve_user(db, payload: dict[str, Any], fallback_user_id: int | None = None) -> User | None:
    user_id = _payload_user_id(payload) or fallback_user_id
    if not user_id:
        return None
    return db.query(User).filter(User.id == user_id).first()


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
                    await room_realtime_connections.send_json(
                        websocket,
                        {"type": "error", "payload": {"room_id": room_id, "message": "Room not found"}},
                    )
                    continue

                user = _resolve_user(db, payload, active_user_id)
                if active_room_id is None:
                    active_room_id = room_id
                    active_user_id = user.id if user else _payload_user_id(payload)
                    await room_realtime_connections.connect_room(room_id, websocket, active_user_id)

                if event_type == "room/snapshot":
                    snapshot = room_state_service.room_snapshot(db, room)
                    db.commit()
                    await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                    continue

                if event_type == "room/join":
                    if user is None:
                        snapshot = room_state_service.room_snapshot(db, room)
                    else:
                        active_user_id = user.id
                        snapshot = room_action_service.join_room(db, room, user, payload)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room/joined", snapshot)
                    await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                    continue

                if event_type == "room/leave":
                    if user is not None:
                        snapshot = room_action_service.leave_room(db, room, user, release_seat=payload.get("release_seat") is True)
                    else:
                        snapshot = room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "room/peer_left", snapshot)
                    continue

                if event_type == "room/heartbeat":
                    if user is not None:
                        snapshot = room_action_service.heartbeat_room(db, room, user)
                    else:
                        snapshot = room_state_service.room_snapshot(db, room, include_chat=False)
                    db.commit()
                    await room_realtime_connections.send_json(websocket, _event_payload("room.snapshot", room_id, snapshot))
                    continue

                if event_type == "seat/take" and user is not None:
                    snapshot = room_action_service.take_seat(db, room, user, _int_payload(payload, "seat_index"))
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "seat/leave" and user is not None:
                    snapshot = room_action_service.leave_seat(db, room, user)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "admin/seat_assign":
                    target_id = _target_user_id(payload)
                    target = db.query(User).filter(User.id == target_id).first() if target_id else None
                    if target:
                        snapshot = room_action_service.take_seat(db, room, target, _int_payload(payload, "seat_index"), actor_user_id=active_user_id)
                    else:
                        snapshot = room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type in {"admin/seat_leave", "admin/seat_leave_lock"}:
                    target_id = _target_user_id(payload)
                    target = db.query(User).filter(User.id == target_id).first() if target_id else None
                    if target:
                        snapshot = room_action_service.leave_seat(db, room, target, actor_user_id=active_user_id)
                    else:
                        snapshot = room_state_service.room_snapshot(db, room)
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

                if event_type == "mic/set_enabled" and user is not None:
                    snapshot = room_action_service.set_mic_enabled(db, room, user, payload.get("enabled") is True)
                    db.commit()
                    await _broadcast_snapshot(room_id, "seat/updated", snapshot)
                    continue

                if event_type == "admin_mute/set":
                    target_id = _target_user_id(payload)
                    if target_id:
                        snapshot = room_action_service.set_admin_mute(db, room, target_id, payload.get("muted") is True, actor_user_id=active_user_id)
                    else:
                        snapshot = room_state_service.room_snapshot(db, room)
                    db.commit()
                    await _broadcast_snapshot(room_id, "admin_mute/updated", snapshot, {"target_user_id": target_id, "admin_muted": payload.get("muted") is True})
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

                if event_type in {"room_chat/send", "room/chat"}:
                    text = str(payload.get("text") or "").strip()
                    if text and user is not None:
                        snapshot = room_action_service.create_chat_message(db, room, user, text, message_type=str(payload.get("message_type") or "text"), metadata=payload)
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
        # Important: never mutate saved room state on raw socket disconnect.
        # Minimize/restore, mobile network changes, browser refreshes, and quick reconnects
        # should not reset seats, mic state, locked seats, room settings, or chat data.
        # Real leave behavior must come from the explicit `room/leave` event only.
        room_realtime_connections.disconnect(websocket)
