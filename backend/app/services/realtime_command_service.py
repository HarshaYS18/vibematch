from __future__ import annotations

import asyncio
import logging
from typing import Any

from fastapi import HTTPException
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.api.routes import room_realtime_commands
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.services.rooms import room_permission_service


logger = logging.getLogger("uvicorn.error")
_TRANSIENT_ROOM_DB_CODES = {"55P03", "40P01", "40001"}
_ROOM_COMMAND_RETRY_DELAYS_SECONDS = (0.075, 0.2)


ROOM_REALTIME_COMMANDS = frozenset({
    "room/join",
    "room/leave",
    "seat/take",
    "seat/leave",
    "seat_invite/send",
    "seat_invite/accept",
    "seat_invite/reject",
    "seat_application/request",
    "seat_application/reject",
    "admin/seat_assign",
    "admin/seat_leave",
    "admin/seat_leave_lock",
    "admin/seat_lock",
    "admin/seat_unlock",
    "mic/set_enabled",
    "admin_mute/set",
    "admin/kick",
    "admin/kick_remove",
    "room_member/request",
    "room_member/approve",
    "room_member/reject",
    "room_member/remove",
    "room_admin/set",
    "room_settings/seat_layout",
    "room_settings/background_theme",
    "room_settings/privacy",
    "room_settings/screenshots",
    "room_settings/images",
    "room_settings/guest_messages",
    "room_settings/apply_mode",
    "room_settings/announcement",
    "room_chat/send",
    "room/chat",
    "room/chat_clear",
    "room/system_message",
    "profile/update",
    "room_cricket/start",
    "room_cricket/end",
    "room_activity/start",
    "room_activity/update",
    "room_activity/end",
    "watch_party/load",
    "watch_party/play",
    "watch_party/pause",
    "watch_party/seek",
    "watch_party/change_content",
    "watch_party/sync",
    "watch_party/end",
    "watch_party/transfer_control",
})

ROOM_EPHEMERAL_COMMANDS = frozenset({
    "room_music/control_external",
    "room_music/stop_external",
    "room_music/producer_started_external",
})

APPLICATION_REALTIME_COMMANDS = ROOM_REALTIME_COMMANDS | ROOM_EPHEMERAL_COMMANDS


def _room_db_sqlstate(exc: OperationalError) -> str:
    original = getattr(exc, "orig", None)
    return str(
        getattr(original, "sqlstate", None)
        or getattr(original, "pgcode", None)
        or ""
    )


async def _execute_room_command_with_retry(
    *,
    room_id: str,
    user_id: int,
    command_type: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    for attempt in range(len(_ROOM_COMMAND_RETRY_DELAYS_SECONDS) + 1):
        try:
            return await room_realtime_commands.execute_room_command_by_ids(
                room_id,
                user_id,
                command_type,
                payload,
            )
        except OperationalError as exc:
            sqlstate = _room_db_sqlstate(exc)
            if (
                sqlstate not in _TRANSIENT_ROOM_DB_CODES
                or attempt >= len(_ROOM_COMMAND_RETRY_DELAYS_SECONDS)
            ):
                raise
            delay = _ROOM_COMMAND_RETRY_DELAYS_SECONDS[attempt]
            logger.warning(
                "realtime_gateway.command_retry room_id=%s user_id=%s "
                "command=%s attempt=%s sqlstate=%s delay_ms=%s",
                room_id,
                user_id,
                command_type,
                attempt + 1,
                sqlstate,
                int(delay * 1000),
            )
            await asyncio.sleep(delay)
    raise RuntimeError("Room command retry loop exhausted")


async def execute_application_realtime_command(
    db: Session,
    user: User,
    *,
    command_type: str,
    room_public_id: str | None,
    conversation_id: str | None,
    activity: str | None,
    payload: dict[str, Any] | None,
    command_id: str | None = None,
) -> dict[str, Any]:
    command = str(command_type or "").strip()
    if command not in APPLICATION_REALTIME_COMMANDS:
        raise HTTPException(status_code=422, detail="Unsupported realtime command")

    room_id = str(room_public_id or "").strip()
    if not room_id:
        raise HTTPException(status_code=422, detail="room_public_id is required")

    if command in ROOM_EPHEMERAL_COMMANDS:
        room = room_realtime_commands.room_or_404(db, room_id)
        room_permission_service.require_room_settings(db, room, user)
        event_payload = dict(payload or {})
        event_payload["room_id"] = room_id
        await room_realtime_connections.broadcast_room(
            room_id,
            {
                "type": command,
                "payload": event_payload,
            },
        )
        return {
            "scope": "room",
            "room_public_id": room_id,
            "state_version": int(room.realtime_version or 0),
            "event_sequence": int(room.realtime_event_sequence or 0),
            "result": "applied",
        }

    safe_command_id = str(command_id or "").strip()
    claimed = False
    if safe_command_id:
        claimed = await room_realtime_connections.claim_command(
            room_id,
            int(user.id),
            safe_command_id,
        )
        if not claimed:
            room = room_realtime_commands.room_or_404(db, room_id)
            snapshot = room_realtime_commands.client_room_snapshot(db, room)
            return {
                "scope": "room",
                "room_public_id": room_id,
                "state_version": int(snapshot.get("state_version") or 0),
                "event_sequence": int(snapshot.get("event_sequence") or 0),
                "result": "duplicate",
            }

    try:
        snapshot = await _execute_room_command_with_retry(
            room_id=room_id,
            user_id=int(user.id),
            command_type=command,
            payload=dict(payload or {}),
        )
    except Exception:
        if claimed and safe_command_id:
            await room_realtime_connections.release_command_claim(
                room_id,
                int(user.id),
                safe_command_id,
            )
        raise

    return {
        "scope": "room",
        "room_public_id": room_id,
        "state_version": int(snapshot.get("state_version") or 0),
        "event_sequence": int(snapshot.get("event_sequence") or 0),
        "result": "applied",
    }
