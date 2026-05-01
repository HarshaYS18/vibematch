from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import ValidationError

from app.schemas.websocket import WebSocketEnvelope
from app.services.room_realtime_state_service import room_realtime_state_service
from app.services.websocket_connection_manager import websocket_manager

router = APIRouter(tags=["WebSocket"])

ROOM_STATE_EVENT_TYPES = {
    "room.seat.occupy": "room.seat.occupied",
    "room.seat.leave": "room.seat.left",
    "room.seat.switch": "room.seat.switched",
    "room.seat.lock": "room.seat.locked",
    "room.seat.unlock": "room.seat.unlocked",
    "room.mic.self_mute": "room.mic.self_muted",
    "room.mic.self_unmute": "room.mic.self_unmuted",
    "room.mic.admin_mute": "room.mic.admin_muted",
    "room.mic.admin_unmute": "room.mic.admin_unmuted",
}


@router.websocket("/ws/rooms/{room_id}")
async def room_websocket(
    websocket: WebSocket,
    room_id: str,
    user_id: str = "guest",
    display_name: str = "Guest",
):
    connection = await websocket_manager.connect(
        websocket=websocket,
        room_id=room_id,
        user_id=user_id,
        display_name=display_name,
    )

    await websocket_manager.send_json(
        websocket,
        {
            "type": "system.connected",
            "payload": {
                "connection_id": connection.connection_id,
                "room_id": room_id,
                "user_id": user_id,
                "display_name": display_name,
                "connected_at": connection.connected_at.isoformat(),
            },
        },
    )
    await websocket_manager.send_json(
        websocket,
        {
            "type": "room.state.snapshot",
            "payload": room_realtime_state_service.snapshot(room_id),
        },
    )
    await _broadcast_presence(room_id)

    try:
        while True:
            raw_message = await websocket.receive_json()
            await _handle_room_event(
                websocket=websocket,
                room_id=room_id,
                user_id=user_id,
                display_name=display_name,
                raw_message=raw_message,
            )
    except WebSocketDisconnect:
        await websocket_manager.disconnect(websocket)
        await _broadcast_presence(room_id)
    except Exception:
        await websocket_manager.disconnect(websocket)
        await _broadcast_presence(room_id)


async def _handle_room_event(
    *,
    websocket: WebSocket,
    room_id: str,
    user_id: str,
    display_name: str,
    raw_message: dict,
) -> None:
    try:
        envelope = WebSocketEnvelope.model_validate(raw_message)
    except ValidationError:
        await websocket_manager.send_json(
            websocket,
            {
                "type": "system.error",
                "ok": False,
                "code": "invalid_event",
                "message": "Invalid WebSocket event payload.",
            },
        )
        return

    if envelope.room_id is not None and envelope.room_id != room_id:
        await websocket_manager.send_json(
            websocket,
            {
                "type": "system.error",
                "request_id": envelope.request_id,
                "ok": False,
                "code": "room_mismatch",
                "message": "Event room_id does not match connected room.",
            },
        )
        return

    if envelope.type == "ping":
        await websocket_manager.send_json(
            websocket,
            {
                "type": "pong",
                "request_id": envelope.request_id,
                "payload": {"server_time": datetime.now(timezone.utc).isoformat()},
            },
        )
        return

    if envelope.type == "room.message.send":
        await _handle_send_room_message(
            room_id=room_id,
            user_id=user_id,
            display_name=display_name,
            envelope=envelope,
        )
        return

    if envelope.type in ROOM_STATE_EVENT_TYPES:
        await _handle_room_state_event(
            room_id=room_id,
            user_id=user_id,
            display_name=display_name,
            envelope=envelope,
        )
        return

    await websocket_manager.send_json(
        websocket,
        {
            "type": "system.error",
            "request_id": envelope.request_id,
            "ok": False,
            "code": "unsupported_event",
            "message": f"Unsupported WebSocket event type: {envelope.type}",
        },
    )


async def _handle_send_room_message(
    *,
    room_id: str,
    user_id: str,
    display_name: str,
    envelope: WebSocketEnvelope,
) -> None:
    text = str(envelope.payload.get("text", "")).strip()

    if not text:
        await websocket_manager.broadcast_to_room(
            room_id=room_id,
            data={
                "type": "system.error",
                "request_id": envelope.request_id,
                "ok": False,
                "code": "empty_message",
                "message": "Message text cannot be empty.",
            },
        )
        return

    if len(text) > 500:
        await websocket_manager.broadcast_to_room(
            room_id=room_id,
            data={
                "type": "system.error",
                "request_id": envelope.request_id,
                "ok": False,
                "code": "message_too_long",
                "message": "Room message cannot exceed 500 characters.",
            },
        )
        return

    await websocket_manager.broadcast_to_room(
        room_id=room_id,
        data={
            "type": "room.message.created",
            "request_id": envelope.request_id,
            "payload": {
                "room_id": room_id,
                "sender_user_id": user_id,
                "sender_name": display_name,
                "text": text,
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
        },
    )


async def _handle_room_state_event(
    *,
    room_id: str,
    user_id: str,
    display_name: str,
    envelope: WebSocketEnvelope,
) -> None:
    event_type = ROOM_STATE_EVENT_TYPES[envelope.type]
    payload = dict(envelope.payload)
    room_state = room_realtime_state_service.apply_event(
        room_id=room_id,
        event_type=envelope.type,
        actor_user_id=user_id,
        actor_name=display_name,
        payload=payload,
    )
    payload.update(
        {
            "room_id": room_id,
            "actor_user_id": user_id,
            "actor_name": display_name,
            "room_state": room_state,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    )

    await websocket_manager.broadcast_to_room(
        room_id=room_id,
        data={
            "type": event_type,
            "request_id": envelope.request_id,
            "payload": payload,
        },
    )
    await websocket_manager.broadcast_to_room(
        room_id=room_id,
        data={
            "type": "room.state.updated",
            "request_id": envelope.request_id,
            "payload": room_state,
        },
    )


async def _broadcast_presence(room_id: str) -> None:
    await websocket_manager.broadcast_to_room(
        room_id=room_id,
        data={
            "type": "room.presence.updated",
            "payload": websocket_manager.room_presence_payload(room_id),
        },
    )
