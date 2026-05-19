from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user_from_token
from app.database import get_db
from app.models.role import RoleName
from app.models.user import User
from app.services import inbox_service, role_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(tags=["Inbox WebSocket"])


async def _user_from_token(token: str, db: Session) -> User | None:
    try:
        return get_current_user_from_token(db, token)
    except (HTTPException, ValueError):
        return None


def _is_staff_for_inbox(user: User) -> bool:
    return role_service.get_primary_role(user) in {
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
        RoleName.SUPERADMIN,
        RoleName.ADMIN,
        RoleName.MONITOR,
        RoleName.CS,
    }


@router.websocket("/ws/inbox")
async def inbox_websocket(websocket: WebSocket, db: Session = Depends(get_db)):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return

    user = await _user_from_token(token, db)
    if not user or user.is_banned or not user.is_active:
        await websocket.close(code=4403)
        return

    await inbox_ws_manager.connect(user.id, websocket, is_staff=_is_staff_for_inbox(user))
    try:
        while True:
            payload = await websocket.receive_json()
            event = payload.get("event")
            if event == "ping":
                await websocket.send_json({"event": "pong"})
                continue

            conversation_id = payload.get("conversation_id")
            if not conversation_id:
                continue

            conversation = inbox_service.get_conversation_for_user(db, user, str(conversation_id))
            if not conversation:
                continue

            participant_ids = inbox_service.participant_user_ids(conversation)
            if event == "typing_start":
                await inbox_ws_manager.broadcast_to_users(
                    participant_ids,
                    {
                        "event": "inbox_typing_start",
                        "conversation_id": conversation.public_id,
                        "user_id": user.id,
                        "display_name": user.display_name or user.username or str(user.public_user_id),
                    },
                )
            elif event == "typing_stop":
                await inbox_ws_manager.broadcast_to_users(
                    participant_ids,
                    {
                        "event": "inbox_typing_stop",
                        "conversation_id": conversation.public_id,
                        "user_id": user.id,
                    },
                )
            elif event == "mark_read":
                participant = next((item for item in conversation.participants if item.user_id == user.id), None)
                if participant:
                    participant.unread_count = 0
                    if conversation.messages:
                        participant.last_read_message_id = conversation.messages[-1].id
                    db.commit()
                await inbox_ws_manager.send_to_user(
                    user.id,
                    {
                        "event": "inbox_messages_read",
                        "conversation_id": conversation.public_id,
                        "reader_user_id": user.id,
                    },
                )
    except WebSocketDisconnect:
        inbox_ws_manager.disconnect(user.id, websocket)
    except Exception:
        inbox_ws_manager.disconnect(user.id, websocket)
        await websocket.close(code=1011)
