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
    execute_room_command_by_ids,
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
_TRANSIENT_ROOM_DB_CODES = {"55P03", "40P01", "40001"}
_ROOM_COMMAND_RETRY_DELAYS_SECONDS = (0.075, 0.2)



def _connected(websocket: WebSocket) -> bool:
    return (
        websocket.client_state == WebSocketState.CONNECTED
        and websocket.application_state == WebSocketState.CONNECTED
    )


def _join_token(payload: dict) -> str:
    return str(payload.get("access_token") or "").strip()


def _room_db_sqlstate(exc: OperationalError) -> str:
    original = getattr(exc, "orig", None)
    return str(
        getattr(original, "sqlstate", None)
        or getattr(original, "pgcode", None)
        or ""
    )


def _is_transient_room_db_error(exc: OperationalError) -> bool:
    return _room_db_sqlstate(exc) in _TRANSIENT_ROOM_DB_CODES


async def _execute_room_command_with_retry(
    db: Session | None,
    *,
    room_id: str,
    user_id: int,
    command_type: str,
    payload: dict,
) -> dict:
    for attempt in range(len(_ROOM_COMMAND_RETRY_DELAYS_SECONDS) + 1):
        try:
            return await execute_room_command_by_ids(
                room_id,
                user_id,
                command_type,
                payload,
            )
        except OperationalError as exc:
            if db is not None:
                db.rollback()
            if (
                not _is_transient_room_db_error(exc)
                or attempt >= len(_ROOM_COMMAND_RETRY_DELAYS_SECONDS)
            ):
                raise
            delay = _ROOM_COMMAND_RETRY_DELAYS_SECONDS[attempt]
            logger.warning(
                "room_realtime.command_retry room_id=%s user_id=%s command=%s attempt=%s sqlstate=%s delay_ms=%s",
                room_id,
                user_id,
                command_type,
                attempt + 1,
                _room_db_sqlstate(exc),
                int(delay * 1000),
            )
            await asyncio.sleep(delay)
    raise RuntimeError("Room command retry loop exhausted")

def _active_room_user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if user is None or user.is_banned or not user.is_active:
        raise HTTPException(status_code=401, detail="Room session is no longer valid")
    return user


def _prepare_room_join(token: str, room_id: str) -> tuple[int, dict | None]:
    with SessionLocal() as db:
        try:
            user = get_current_user_from_token(db, token)
            user_id = int(user.id)
            room = room_or_404(db, room_id)
            participant = (
                db.query(RoomParticipant)
                .filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user_id)
                .with_for_update()
                .first()
            )
            if participant is None or not participant.is_active:
                db.rollback()
                return user_id, None
            room_permission_service.require_join(db, room, user)
            now = datetime.utcnow()
            participant.last_seen_at = now
            participant.left_at = None
            user.last_seen_at = now
            snapshot = client_room_snapshot(db, room)
            db.commit()
            return user_id, snapshot
        except Exception:
            db.rollback()
            raise


def _room_snapshot_for_user(room_id: str, user_id: int, include_chat: bool = True) -> dict:
    with SessionLocal() as db:
        user = _active_room_user(db, user_id)
        room = room_or_404(db, room_id)
        room_permission_service.require_room_view(db, room, user)
        snapshot = client_room_snapshot(db, room, include_chat=include_chat)
        db.commit()
        return snapshot


def _room_heartbeat_for_user(room_id: str, user_id: int) -> dict:
    with SessionLocal() as db:
        try:
            user = _active_room_user(db, user_id)
            room = room_or_404(db, room_id, for_update=True)
            room_action_service.heartbeat_room(db, room, user)
            db.commit()
            db.refresh(room)
            snapshot = client_room_snapshot(db, room, include_chat=False)
            db.commit()
            return snapshot
        except Exception:
            db.rollback()
            raise

def _disconnect_is_superseded(
    participant: RoomParticipant,
    disconnected_at: datetime,
) -> bool:
    return bool(
        participant.last_seen_at is not None
        and participant.last_seen_at > disconnected_at
    )


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


async def _leave_current_room_connection(
    websocket: WebSocket,
    *,
    room_id: str,
    user: User | int,
    db: Session | None,
    command_id: str,
    command_type: str,
    payload: dict,
) -> bool:
    """Leave this websocket without evicting another live session."""
    del db
    user_id = int(user if isinstance(user, int) else user.id)
    await room_realtime_connections.release_connection(websocket)

    if await room_realtime_connections.has_room_user_connections(room_id, user_id):
        snapshot = await asyncio.to_thread(_room_snapshot_for_user, room_id, user_id)
        logger.info(
            "room_realtime.connection_leave_preserved_presence room_id=%s user_id=%s",
            room_id,
            user_id,
        )
    else:
        snapshot = await execute_room_command_by_ids(
            room_id,
            user_id,
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
    try:
        await websocket.close(code=1000)
    except Exception:
        pass
    return True

def _finalize_disconnect_db(
    room_id: str,
    user_id: int,
    disconnected_at: datetime,
) -> tuple[bool, dict] | None:
    with SessionLocal() as db:
        room = room_or_404(db, room_id, for_update=True)
        user = db.query(User).filter(User.id == user_id).first()
        participant = (
            db.query(RoomParticipant)
            .filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user_id)
            .with_for_update()
            .first()
        )
        if user is None or participant is None or not participant.is_active:
            return None
        if _disconnect_is_superseded(participant, disconnected_at):
            return None
        was_stealth = bool(participant.is_stealth)
        logger.info(
            "room_realtime.disconnect_finalize_deactivate room_id=%s user_id=%s disconnected_at=%s last_seen_at=%s",
            room_id,
            user_id,
            disconnected_at.isoformat(),
            participant.last_seen_at.isoformat() if participant.last_seen_at else None,
        )
        room_action_service.leave_room(db, room, user, release_seat=True)
        db.commit()
        db.refresh(room)
        snapshot = client_room_snapshot(db, room)
        db.commit()
        return was_stealth, snapshot


async def _finalize_disconnect(
    room_id: str,
    user_id: int,
    disconnected_at: datetime,
) -> None:
    await asyncio.sleep(_DISCONNECT_GRACE_SECONDS)
    if await room_realtime_connections.has_room_user_connections(room_id, user_id):
        return
    result = await asyncio.to_thread(_finalize_disconnect_db, room_id, user_id, disconnected_at)
    if result is None:
        return
    was_stealth, snapshot = result
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
                try:
                    token = _join_token(payload)
                    if not token:
                        raise HTTPException(status_code=401, detail="Room access token required")
                    authenticated_user_id, snapshot = await asyncio.to_thread(
                        _prepare_room_join,
                        token,
                        room_id,
                    )
                    if snapshot is None:
                        snapshot = await execute_room_command_by_ids(
                            room_id,
                            authenticated_user_id,
                            "room/join",
                            payload,
                        )
                except HTTPException as exc:
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
                    logger.exception(
                        "room_realtime.join_failed room_id=%s command_id=%s",
                        room_id,
                        command_id,
                    )
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

            claimed = False
            try:
                if active_user_id is None:
                    raise HTTPException(status_code=401, detail="Room session is no longer valid")

                if command_type == "room/snapshot":
                    snapshot = await asyncio.to_thread(_room_snapshot_for_user, room_id, active_user_id)
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
                    snapshot = await asyncio.to_thread(_room_heartbeat_for_user, room_id, active_user_id)
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

                if command_type == "room/leave":
                    await _leave_current_room_connection(
                        websocket,
                        room_id=room_id,
                        user=active_user_id,
                        db=None,
                        command_id=command_id,
                        command_type=command_type,
                        payload=payload,
                    )
                    active_room_id = None
                    active_user_id = None
                    break

                if command_id:
                    claimed = await room_realtime_connections.claim_command(
                        room_id,
                        active_user_id,
                        command_id,
                    )
                    if not claimed:
                        snapshot = await asyncio.to_thread(_room_snapshot_for_user, room_id, active_user_id)
                        await _send_ack(
                            websocket,
                            room_id=room_id,
                            command_id=command_id,
                            command_type=command_type,
                            state_version=int(snapshot.get("state_version") or 0),
                            result="duplicate",
                        )
                        continue

                snapshot = await _execute_room_command_with_retry(
                    None,
                    room_id=room_id,
                    user_id=active_user_id,
                    command_type=command_type,
                    payload=payload,
                )
                await _send_ack(
                    websocket,
                    room_id=room_id,
                    command_id=command_id,
                    command_type=command_type,
                    state_version=int(snapshot.get("state_version") or 0),
                )
            except HTTPException as exc:
                if claimed and command_id and active_user_id is not None:
                    await room_realtime_connections.release_command_claim(room_id, active_user_id, command_id)
                await _send_error(
                    websocket,
                    room_id=room_id,
                    command_id=command_id,
                    command_type=command_type,
                    status_code=exc.status_code,
                    message=str(exc.detail),
                )
                if exc.status_code == 401:
                    break
            except Exception:
                logger.exception(
                    "room_realtime.command_failed room_id=%s user_id=%s command=%s command_id=%s",
                    room_id,
                    active_user_id,
                    command_type,
                    command_id,
                )
                if claimed and command_id and active_user_id is not None:
                    await room_realtime_connections.release_command_claim(room_id, active_user_id, command_id)
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
