from __future__ import annotations

from dataclasses import dataclass

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.user import User
from app.services import inbox_service
from app.websocket.inbox_ws import inbox_ws_manager


ALLOWED_INBOX_REALTIME_COMMANDS = {
    "inbox.chat_activity",
    "inbox.typing_start",
    "inbox.typing_stop",
    "inbox.mark_read",
}


@dataclass(frozen=True)
class InboxRealtimeCommandResult:
    conversation_id: str
    recipient_ids: tuple[int, ...]


def _conversation_context(
    db: Session,
    user: User,
    conversation_id: str,
    *,
    mark_read: bool,
) -> InboxRealtimeCommandResult:
    if user.is_banned or not user.is_active:
        raise HTTPException(status_code=403, detail="Inbox session is no longer valid")

    conversation = inbox_service.get_conversation_for_user(
        db,
        user,
        conversation_id,
    )
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")

    participant_ids = inbox_service.participant_user_ids(conversation)
    recipient_ids = tuple(
        participant_id
        for participant_id in participant_ids
        if participant_id != user.id
    )
    public_id = str(conversation.public_id)

    if mark_read:
        inbox_service.mark_messages_read_for_user(db, conversation, user)

    return InboxRealtimeCommandResult(
        conversation_id=public_id,
        recipient_ids=recipient_ids,
    )


async def execute_inbox_realtime_command(
    db: Session,
    user: User,
    *,
    command_type: str,
    conversation_id: str,
    activity: str | None = None,
) -> InboxRealtimeCommandResult:
    if command_type not in ALLOWED_INBOX_REALTIME_COMMANDS:
        raise HTTPException(status_code=422, detail="Unsupported realtime command")

    result = _conversation_context(
        db,
        user,
        conversation_id,
        mark_read=command_type == "inbox.mark_read",
    )
    display_name = (
        user.display_name
        or user.username
        or str(user.public_user_id)
    )

    if command_type == "inbox.chat_activity":
        resolved_activity = (activity or "idle").strip() or "idle"
        await inbox_ws_manager.broadcast_to_users(
            list(result.recipient_ids),
            {
                "event": "inbox_chat_activity",
                "conversation_id": result.conversation_id,
                "activity": resolved_activity,
                "user_id": user.id,
                "display_name": display_name,
                "from_self": False,
            },
        )
    elif command_type == "inbox.typing_start":
        await inbox_ws_manager.broadcast_to_users(
            list(result.recipient_ids),
            {
                "event": "inbox_typing_start",
                "conversation_id": result.conversation_id,
                "user_id": user.id,
                "display_name": display_name,
            },
        )
    elif command_type == "inbox.typing_stop":
        await inbox_ws_manager.broadcast_to_users(
            list(result.recipient_ids),
            {
                "event": "inbox_typing_stop",
                "conversation_id": result.conversation_id,
                "user_id": user.id,
            },
        )
    elif command_type == "inbox.mark_read":
        await inbox_ws_manager.broadcast_to_users(
            [user.id, *result.recipient_ids],
            {
                "event": "inbox_messages_read",
                "conversation_id": result.conversation_id,
                "reader_user_id": user.id,
            },
        )

    return result
