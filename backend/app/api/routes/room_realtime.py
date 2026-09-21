from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.exc import OperationalError
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
logger = logging.getLogger("uvicorn.error")
_DISCONNECT_GRACE_SECONDS = 5
_TRANSIENT_DB_CODES = {"40P01", "55P03", "40001"}


def _connected(websocket: WebSocket) -> bool:
    return (
        websocket.client_state == WebSocketState.CONNECTED
        and websocket.application_state == WebSocketState.CONNECTED
    )


def _join_token(payload: dict) -> str:
    return str(payload.get("access_token") or "").strip()


def _disconnect_is_superseded(
    participant: RoomParticipant,
    disconnected_at: datetime,
) -> bool:
    return bool(
        participant.last_seen_at is not None
        and participant.last_seen_at > disconnected_at
    )


def _is_transient_db_lock_error(exc: OperationalError) -> bool:
    original = getattr(exc, "orig", None)
    code = getattr(original, "sqlstate", None) or getattr(original, "pgcode", None)
    return str(code or "") in _TRANSIENT_DB_CODES


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


async def _finalize_disconnect(
    room_id: str,
    user_id: int,
    disconnected_at: datetime,
) -> None:
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
            .with_for_update()
            .first()
        )
        if user is None or participant is None or not participant.is_active:
            return

        # A replacement websocket or REST join can begin during the disconnect
        # grace window before it is visible in the connection manager. Those
        # joins refresh last_seen_at under the same participant row lock. Do
        # not let this stale disconnect task deactivate a newer room session.
        if _disconnect_is_superseded(participant, disconnected_at):
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

                authenticated_user_id: int | None = None
                with SessionLocal() as db:
                    try:
                        token = _join_token(payload)
                        if not token:
                            raise HTTPException(status_code=401, detail="Room access token required")
                        user = get_current_user_from_token(db, token)
                        # Capture the scalar before execute_room_command commits. SQLAlchemy
                        # expires ORM attributes on commit; reading user.id after the session
                        # closes raises DetachedInstanceError and used to tear down every room
                        # websocket immediately after a successful join.
                        authenticated_user_id = int(user.id)
                        room = room_or_404(db, room_id, for_update=True)

                        # The REST room-enter flow normally establishes authoritative
                        # participant/presence state before the realtime socket attaches.
                        # Do not repeat the same write transaction when that state is already
                        # active. Besides being redundant, concurrent REST + websocket joins
                        # can contend on user_room_presence and produce PostgreSQL deadlocks.
                        participant = (
                            db.query(RoomParticipant)
                            .filter(
                                RoomParticipant.room_id == room.id,
                                RoomParticipant.user_id == authenticated_user_id,
                            )
                            .with_for_update()
                            .first()
                        )
                        if participant is not None and participant.is_active:
                            room_permission_service.require_join(db, room, user)
                            now = datetime.utcnow()
                            participant.last_seen_at = now
                            participant.left_at = None
                            user.last_seen_at = now
                            snapshot = client_room_snapshot(db, room)
                            db.commit()
                        else:
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
                    except Exception:
                        db.rollback()
                        await _send_error(
                            websocket,
                            room_id=room_id,
                            command_id=command_id,
                            command_type=command_type,
                            status_code=500,
                            message="Room realtime join failed; reconnecting",
                        )
                        try:
                            await websocket.close(code=1011)
                        except Exception:
                            pass
                        break

                if authenticated_user_id is None:
                    await _send_error(
                        websocket,
                        room_id=room_id,
                        command_id=command_id,
                        command_type=command_type,
                        status_code=401,
                        message="Room authentication failed",
                    )
                    continue

                active_room_id = room_id
                active_user_id = authenticated_user_id
                await room_realtime_connections.connect_room(
                    room_id,
                    websocket,
                    authenticated_user_id,
                )

                # Existing room clients receive room/joined from the authoritative join
                # transaction. The joining socket was not registered yet, so send exactly
                # one direct join event to it as the lifecycle signal that also starts the
                # mediasoup audio session on Flutter.
                await room_realtime_connections.send_json(
                    websocket,
                    {
                        "type": "room/joined",
                        "payload": {
                            "room_id": room_id,
                            "room": snapshot,
                            "target_user_id": authenticated_user_id,
                        },
                    },
                )
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

                    try:
                        snapshot = await execute_room_command(
                            db,
                            room,
                            user,
                            command_type,
                            payload,
                        )
                    except OperationalError as exc:
                        if not _is_transient_db_lock_error(exc):
                            raise
                        db.rollback()
                        logger.warning(
                            "room_realtime.command_lock_retry room_id=%s user_id=%s command=%s command_id=%s sqlstate=%s",
                            room_id,
                            active_user_id,
                            command_type,
                            command_id,
                            getattr(getattr(exc, "orig", None), "sqlstate", None)
                            or getattr(getattr(exc, "orig", None), "pgcode", None),
                        )
                        await asyncio.sleep(0.075)
                        user = db.query(User).filter(User.id == active_user_id).first()
                        if user is None or user.is_banned or not user.is_active:
                            raise HTTPException(
                                status_code=401,
                                detail="Room session is no longer valid",
                            )
                        room = room_or_404(db, room_id)
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
                    logger.exception(
                        "room_realtime.command_failed room_id=%s user_id=%s command=%s command_id=%s",
                        room_id,
                        active_user_id,
                        command_type,
                        command_id,
                    )
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
        disconnected_at = datetime.utcnow()
        released = await room_realtime_connections.release_connection(websocket)
        for room_id, user_id in released:
            asyncio.create_task(
                _finalize_disconnect(room_id, user_id, disconnected_at)
            )
