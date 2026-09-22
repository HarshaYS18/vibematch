import asyncio
from dataclasses import dataclass

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect

from app.api.routes.users import get_current_user_from_token
from app.database import SessionLocal
from app.models.role import RoleName
from app.models.user import User
from app.services import inbox_service, role_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(tags=["Inbox WebSocket"])


@dataclass(frozen=True)
class InboxSocketUser:
    id: int
    public_user_id: int
    display_name: str | None
    username: str | None
    is_staff: bool


def _is_staff_for_inbox(user: User) -> bool:
    return role_service.get_primary_role(user) in {
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
        RoleName.SUPERADMIN,
        RoleName.ADMIN,
        RoleName.MONITOR,
        RoleName.CS,
    }


def _load_socket_user(token: str) -> InboxSocketUser | None:
    with SessionLocal() as db:
        try:
            user = get_current_user_from_token(db, token)
            return InboxSocketUser(
                id=int(user.id),
                public_user_id=int(user.public_user_id),
                display_name=user.display_name,
                username=user.username,
                is_staff=_is_staff_for_inbox(user),
            )
        except (HTTPException, ValueError):
            return None


def _conversation_context(
    user_id: int,
    conversation_id: str,
    *,
    mark_read: bool,
) -> tuple[str, list[int]] | None:
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if user is None or user.is_banned or not user.is_active:
            raise HTTPException(status_code=403, detail="Inbox session is no longer valid")
        conversation = inbox_service.get_conversation_for_user(db, user, conversation_id)
        if not conversation:
            return None
        participant_ids = inbox_service.participant_user_ids(conversation)
        recipient_ids = [participant_id for participant_id in participant_ids if participant_id != user_id]
        public_id = str(conversation.public_id)
        if mark_read:
            participant = next((item for item in conversation.participants if item.user_id == user_id), None)
            if participant:
                participant.unread_count = 0
                if conversation.messages:
                    participant.last_read_message_id = conversation.messages[-1].id
                db.commit()
        return public_id, recipient_ids


async def _broadcast_presence(user_id: int, is_online: bool) -> None:
    await inbox_ws_manager.broadcast_all_users(
        {
            "event": "inbox_presence_updated",
            "user_id": user_id,
            "is_online": is_online,
        }
    )


@router.websocket("/ws/inbox")
async def inbox_websocket(websocket: WebSocket):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return

    user = await asyncio.to_thread(_load_socket_user, token)
    if user is None:
        await websocket.close(code=4403)
        return

    became_online = await inbox_ws_manager.connect(
        user.id,
        websocket,
        is_staff=user.is_staff,
    )
    try:
        if became_online:
            await _broadcast_presence(user.id, True)
        while True:
            payload = await websocket.receive_json()
            event = payload.get("event")
            if event == "ping":
                await websocket.send_json({"event": "pong"})
                continue

            conversation_id = payload.get("conversation_id")
            if not conversation_id:
                continue

            try:
                context = await asyncio.to_thread(
                    _conversation_context,
                    user.id,
                    str(conversation_id),
                    mark_read=event == "mark_read",
                )
            except HTTPException:
                await websocket.close(code=4403)
                break
            if context is None:
                continue
            conversation_public_id, recipient_ids = context

            if event == "chat_activity":
                activity = str(payload.get("activity") or "idle").strip() or "idle"
                await inbox_ws_manager.broadcast_to_users(
                    recipient_ids,
                    {
                        "event": "inbox_chat_activity",
                        "conversation_id": conversation_public_id,
                        "activity": activity,
                        "user_id": user.id,
                        "display_name": user.display_name or user.username or str(user.public_user_id),
                        "from_self": False,
                    },
                )
            elif event == "typing_start":
                await inbox_ws_manager.broadcast_to_users(
                    recipient_ids,
                    {
                        "event": "inbox_typing_start",
                        "conversation_id": conversation_public_id,
                        "user_id": user.id,
                        "display_name": user.display_name or user.username or str(user.public_user_id),
                    },
                )
            elif event == "typing_stop":
                await inbox_ws_manager.broadcast_to_users(
                    recipient_ids,
                    {
                        "event": "inbox_typing_stop",
                        "conversation_id": conversation_public_id,
                        "user_id": user.id,
                    },
                )
            elif event == "mark_read":
                await inbox_ws_manager.send_to_user(
                    user.id,
                    {
                        "event": "inbox_messages_read",
                        "conversation_id": conversation_public_id,
                        "reader_user_id": user.id,
                    },
                )
    except WebSocketDisconnect:
        pass
    except Exception:
        try:
            await websocket.close(code=1011)
        except Exception:
            pass
    finally:
        still_online = await inbox_ws_manager.release_connection(user.id, websocket)
        if not still_online:
            await _broadcast_presence(user.id, False)
