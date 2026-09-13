from __future__ import annotations

import asyncio
import json

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from starlette.websockets import WebSocketState

from app.api.routes.room_realtime_commands import (
    client_room_snapshot,
    execute_room_command,
    room_or_404,
)
from app.api.routes.users import get_current_user, get_current_user_from_token
from app.database import SessionLocal, get_db
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.services.rooms import room_action_service, room_permission_service


router = APIRouter(tags=["Room Realtime"])
_DISCONNECT_GRACE_SECONDS = 5


def _connected(websocket: WebSocket) -> bool:
    return (
        websocket.client_state == WebSocketState.CONNECTED
        and websocket.application_state == WebSocketState.CONNECTED
    )


def _join_token(payload: dict) -> str:
    return str(payload.get("access_token") or "").strip()


async def _send_ack(
    websocket: WebSocket,
    *,
    room_id: str,
    command_id: str,
    command_type: str,
    state_version: int,
    result: str = "applied",
) -> None:
    await room_realtime_connections.send_json(
        websocket,
        {
            "type": "command/ack",
            "payload": {
                "room_id": room_id,
                "command_id": command_id,
                "command_type": command_type,
                "result": result,
                "state_version": state_version,
            },
        },
    )


async def _send_error(
    websocket: WebSocket,
    *,
    room_id: str,
    command_id: str,
    command_type: str,
    status_code: int,
    message: str,
) -> None:
    await room_realtime_connections.send_json(
        websocket,
        {
            "type": "command/error",
            "payload": {
                "room_id": room_id,
                "command_id": command_id,
                "command_type": command_type,
                "status_code": status_code,
                "message": message,
            },
        },
    )


async def _finalize_disconnect(room_id: str, user_id: int) -> None:
    await asyncio.sleep(_DISCONNECT_GRACE_SECONDS)
    if await room_realtime_connections.has_room_user_connections(room_id, user_id):
        return

    with SessionLocal() as db:
        room = room_or_404(db, room_id, for_update=True)
        user = db.query(User).filter(User.id == user_id).first()
        participant = (
            db.query(RoomParticipant)
            .filter(
                RoomParticipant.room_id == room.id,
                RoomParticipant.user_id == user_id,
            )
            .first()
        )
        if user is None or participant is None or not participant.is_active:
            return
        was_stealth = bool(participant.is_stealth)
        room_action_service.leave_room(db, room, user, release_seat=True)
        db.commit()
        db.refresh(room)
        snapshot = client_room_snapshot(db, room)
        db.commit()

    if not was_stealth:
        await room_realtime_connections.broadcast_room(
            room_id,
            {
                "type": "room/peer_left",
                "payload": {
                    "room_id": room_id,
                    "room": snapshot,
                    "target_user_id": user_id,
                    "reason": "socket_disconnected",
                },
            },
        )


@router.get("/rooms/{room_public_id}/realtime-snapshot")
def get_room_realtime_snapshot(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = room_or_404(db, room_public_id)
    room_permission_service.require_room_view(db, room, current_user)
    snapshot = client_room_snapshot(db, room)
    db.commit()
    return {"room_id": room_public_id, "room": snapshot}


@router.websocket("/ws/room-realtime")
async def room_realtime_socket(websocket: WebSocket) -> None:
    active_room_id: str | None = None
    active_user_id: int | None = None
    await websocket.accept()

    try:
        while _connected(websocket):
            try:
                raw = await websocket.receive_text()
            except (WebSocketDisconnect, RuntimeError):
                break

            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await _send_error(
                    websocket,
                    room_id=active_room_id or "",
                    command_id="",
                    command_type="",
                    status_code=400,
                    message="Invalid room command JSON",
                )
                continue

            if not isinstance(message, dict):
                continue

            command_type = str(message.get("type") or "").strip()
            payload = message.get("payload") if isinstance(message.get("payload"), dict) else {}
            command_id = str(message.get("command_id") or payload.get("command_id") or "").strip()
            room_id = str(payload.get("room_id") or active_room_id or "").strip()

            if active_room_id is None:
                if command_type != "room/join" or not room_id:
                    await _send_error(
                        websocket,
                        room_id=room_id,
                        command_id=command_id,
                        command_type=command_type,
                        status_code=401,
                        message="room/join must be the first authenticated command",
                    )
                    continue

                with SessionLocal() as db:
                    try:
                        token = _join_token(payload)
                        if not token:
                            raise HTTPException(status_code=401, detail="Room access token required")
                        user = get_current_user_from_token(db, token)
                        room = room_or_404(db, room_id)
                        snapshot = await execute_room_command(
                            db,
                            room,
                            user,
                            "room/join",
                            payload,
                        )
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

                active_room_id = room_id
                active_user_id = user.id
                await room_realtime_connections.connect_room(room_id, websocket, user.id)
                await room_realtime_connections.send_json(
                    websocket,
                    {"type": "room.snapshot", "payload": {"room_id": room_id, "room": snapshot}},
                )
                await _send_ack(
                    websocket,
                    room_id=room_id,
                    command_id=command_id,
                    command_type=command_type,
                    state_version=int(snapshot.get("state_version") or 0),
                )
                continue

            if room_id != active_room_id:
                await _send_error(
                    websocket,
                    room_id=room_id,
                    command_id=command_id,
                    command_type=command_type,
                    status_code=409,
                    message="This socket is bound to a different room",
                )
                continue

            await room_realtime_connections.touch_connection(websocket)

            with SessionLocal() as db:
                user = db.query(User).filter(User.id == active_user_id).first()
                if user is None or user.is_banned or not user.is_active:
                    await _send_error(
                        websocket,
                        room_id=room_id,
                        command_id=command_id,
                        command_type=command_type,
                        status_code=401,
                        message="Room session is no longer valid",
                    )
                    break

                claimed = False
                try:
                    room = room_or_404(db, room_id)

                    if command_type == "room/snapshot":
                        room_permission_service.require_room_view(db, room, user)
                        snapshot = client_room_snapshot(db, room)
                        db.commit()
                        await room_realtime_connections.send_json(
                            websocket,
                            {"type": "room.snapshot", "payload": {"room_id": room_id, "room": snapshot}},
                        )
                        await _send_ack(
                            websocket,
                            room_id=room_id,
                            command_id=command_id,
                            command_type=command_type,
                            state_version=int(snapshot.get("state_version") or 0),
                        )
                        continue

                    if command_type == "room/heartbeat":
                        locked_room = room_or_404(db, room_id, for_update=True)
                        room_action_service.heartbeat_room(db, locked_room, user)
                        db.commit()
                        db.refresh(locked_room)
                        snapshot = client_room_snapshot(db, locked_room, include_chat=False)
                        db.commit()
                        await room_realtime_connections.send_json(
                            websocket,
                            {"type": "room.snapshot", "payload": {"room_id": room_id, "room": snapshot}},
                        )
                        await _send_ack(
                            websocket,
                            room_id=room_id,
                            command_id=command_id,
                            command_type=command_type,
                            state_version=int(snapshot.get("state_version") or 0),
                        )
                        continue

                    if command_id:
                        claimed = await room_realtime_connections.claim_command(
                            room_id,
                            user.id,
                            command_id,
                        )
                        if not claimed:
                            snapshot = client_room_snapshot(db, room)
                            db.commit()
                            await _send_ack(
                                websocket,
                                room_id=room_id,
                                command_id=command_id,
                                command_type=command_type,
                                state_version=int(snapshot.get("state_version") or 0),
                                result="duplicate",
                            )
                            continue

                    snapshot = await execute_room_command(
                        db,
                        room,
                        user,
                        command_type,
                        payload,
                    )
                    await _send_ack(
                        websocket,
                        room_id=room_id,
                        command_id=command_id,
                        command_type=command_type,
                        state_version=int(snapshot.get("state_version") or 0),
                    )
                except HTTPException as exc:
                    db.rollback()
                    if claimed and command_id:
                        await room_realtime_connections.release_command_claim(
                            room_id,
                            user.id,
                            command_id,
                        )
                    await _send_error(
                        websocket,
                        room_id=room_id,
                        command_id=command_id,
                        command_type=command_type,
                        status_code=exc.status_code,
                        message=str(exc.detail),
                    )
                except Exception:
                    db.rollback()
                    if claimed and command_id:
                        await room_realtime_connections.release_command_claim(
                            room_id,
                            user.id,
                            command_id,
                        )
                    await _send_error(
                        websocket,
                        room_id=room_id,
                        command_id=command_id,
                        command_type=command_type,
                        status_code=500,
                        message="Room command failed",
                    )
    finally:
        released = await room_realtime_connections.release_connection(websocket)
        for room_id, user_id in released:
            asyncio.create_task(_finalize_disconnect(room_id, user_id))
