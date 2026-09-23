from __future__ import annotations

from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.api.routes import room_realtime_commands
from app.models.user import User
from app.services import inbox_realtime_command_service


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

INBOX_REALTIME_COMMANDS = frozenset(
    inbox_realtime_command_service.ALLOWED_INBOX_REALTIME_COMMANDS
)

APPLICATION_REALTIME_COMMANDS = ROOM_REALTIME_COMMANDS | INBOX_REALTIME_COMMANDS


async def execute_application_realtime_command(
    db: Session,
    user: User,
    *,
    command_type: str,
    room_public_id: str | None,
    conversation_id: str | None,
    activity: str | None,
    payload: dict[str, Any] | None,
) -> dict[str, Any]:
    command = str(command_type or "").strip()
    if command not in APPLICATION_REALTIME_COMMANDS:
        raise HTTPException(status_code=422, detail="Unsupported realtime command")

    if command in INBOX_REALTIME_COMMANDS:
        if not conversation_id or not conversation_id.strip():
            raise HTTPException(status_code=422, detail="conversation_id is required")
        result = await inbox_realtime_command_service.execute_inbox_realtime_command(
            db,
            user,
            command_type=command,
            conversation_id=conversation_id,
            activity=activity,
        )
        return {
            "scope": "inbox",
            "conversation_id": result.conversation_id,
        }

    room_id = str(room_public_id or "").strip()
    if not room_id:
        raise HTTPException(status_code=422, detail="room_public_id is required")

    snapshot = await room_realtime_commands.execute_room_command_by_ids(
        room_id,
        int(user.id),
        command,
        dict(payload or {}),
    )
    return {
        "scope": "room",
        "room_public_id": room_id,
        "state_version": int(snapshot.get("state_version") or 0),
        "event_sequence": int(snapshot.get("event_sequence") or 0),
    }
