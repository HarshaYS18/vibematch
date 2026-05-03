from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import SessionLocal
from app.models.user import User
from app.websocket.live_room_manager import live_room_manager


router = APIRouter()

ALLOWED_CLIENT_EVENT_TYPES = {
    "room/ping",
    "room/chat/message",
    "room/seat/request",
    "room/seat/take",
    "room/seat/leave",
    "room/seat/mute_state",
    "room/join_request",
    "room/join_request/resolve",
    "room/settings/update",
    "room/gift/sent",
    "room/reaction/sent",
    "room/typing",
}

MAX_TEXT_LENGTH = 600
MAX_EVENT_KEYS = 24


def _get_user_from_token(db: Session, token: str | None) -> User | None:
    if not token:
        return None

    payload = decode_access_token(token)
    if not payload:
        return None

    subject = payload.get("sub")
    if subject is None:
        return None

    try:
        user_id = int(subject)
    except (TypeError, ValueError):
        return None

    return db.query(User).filter(User.id == user_id).first()


def _sanitize_event(event: dict[str, Any], user: User) -> dict[str, Any]:
    event_type = str(event.get("type") or "")
    if event_type not in ALLOWED_CLIENT_EVENT_TYPES:
        raise ValueError("unsupported live room event type")

    if len(event.keys()) > MAX_EVENT_KEYS:
        raise ValueError("live room event has too many fields")

    sanitized: dict[str, Any] = {
        "type": event_type,
        "sender": {
            "user_id": user.id,
            "public_user_id": user.public_user_id,
            "display_name": user.display_name,
        },
    }

    for key, value in event.items():
        if key in {"type", "sender", "room_id", "server_time"}:
            continue
        if isinstance(value, str):
            sanitized[key] = value[:MAX_TEXT_LENGTH]
        elif isinstance(value, (int, float, bool)) or value is None:
            sanitized[key] = value
        elif isinstance(value, list):
            sanitized[key] = value[:20]
        elif isinstance(value, dict):
            sanitized[key] = {str(k): v for k, v in list(value.items())[:20]}

    return sanitized


@router.websocket("/ws/rooms/{room_id}")
async def live_room_websocket(websocket: WebSocket, room_id: str):
    token = websocket.query_params.get("token")
    db = SessionLocal()
    user: User | None = None

    try:
        user = _get_user_from_token(db, token)
        if user is None or not user.is_active or user.is_banned:
            await websocket.close(code=4401, reason="unauthorized")
            return

        await live_room_manager.connect(
            websocket=websocket,
            room_id=room_id,
            user_id=user.id,
            public_user_id=user.public_user_id,
            display_name=user.display_name,
        )
        await live_room_manager.send_snapshot(room_id=room_id, websocket=websocket)
        await live_room_manager.broadcast(
            room_id=room_id,
            event={
                "type": "room/user_joined",
                "user": {
                    "user_id": user.id,
                    "public_user_id": user.public_user_id,
                    "display_name": user.display_name,
                },
                "at": datetime.now(timezone.utc).isoformat(),
            },
            exclude_user_id=user.id,
        )
        await live_room_manager.broadcast_presence(room_id=room_id)

        while True:
            incoming = await websocket.receive_json()
            if not isinstance(incoming, dict):
                await websocket.send_json({"type": "room/error", "message": "invalid event payload"})
                continue

            try:
                event = _sanitize_event(incoming, user)
            except ValueError as error:
                await websocket.send_json({"type": "room/error", "message": str(error)})
                continue

            if event["type"] == "room/ping":
                await websocket.send_json({"type": "room/pong", "server_time": datetime.now(timezone.utc).isoformat()})
                continue

            await live_room_manager.broadcast(room_id=room_id, event=event)

    except WebSocketDisconnect:
        pass
    finally:
        if user is not None:
            disconnected = live_room_manager.disconnect(room_id=room_id, user_id=user.id)
            if disconnected:
                await live_room_manager.broadcast(
                    room_id=room_id,
                    event={
                        "type": "room/user_left",
                        "user": {
                            "user_id": user.id,
                            "public_user_id": user.public_user_id,
                            "display_name": user.display_name,
                        },
                        "at": datetime.now(timezone.utc).isoformat(),
                    },
                    exclude_user_id=user.id,
                )
                await live_room_manager.broadcast_presence(room_id=room_id)
        db.close()


@router.get("/live-room-ws/stats")
def live_room_websocket_stats():
    return {"ok": True, **live_room_manager.stats()}
