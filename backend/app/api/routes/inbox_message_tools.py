from datetime import datetime, timedelta

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.inbox import InboxDeleteForMeResponse, InboxMessageActionRequest, InboxMessageResponse
from app.services import inbox_preference_service, inbox_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(tags=["Inbox Message Tools"])

EDIT_WINDOW = timedelta(minutes=15)


@router.patch("/conversations/{conversation_id}/messages/{message_id}/edit", response_model=InboxMessageResponse)
def edit_message_text(
    conversation_id: str,
    message_id: str,
    request: InboxMessageActionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if conversation.is_official:
        raise HTTPException(status_code=403, detail="Official team messages cannot be edited.")

    message = next((item for item in conversation.messages if item.public_id == message_id), None)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    if message.sender_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own messages.")
    if message.message_type != "text":
        raise HTTPException(status_code=403, detail="Only text messages can be edited.")
    if message.created_at is None or datetime.utcnow() > message.created_at + EDIT_WINDOW:
        raise HTTPException(status_code=403, detail="Messages can only be edited within 15 minutes.")

    text = (request.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Message text is required.")

    metadata = dict(message.metadata_json or {})
    metadata.setdefault("edit_history", []).append(
        {
            "text": message.text,
            "edited_at": datetime.utcnow().isoformat() + "Z",
        }
    )
    metadata["edited_at"] = datetime.utcnow().isoformat() + "Z"
    metadata["edited_by_user_id"] = current_user.id
    message.text = text
    message.metadata_json = metadata
    conversation.updated_at = datetime.utcnow()
    db.add(message)
    db.add(conversation)
    db.commit()
    db.refresh(message)

    participant_ids = inbox_service.participant_user_ids(conversation)
    message_payload = inbox_service.message_to_dict(message, current_user)
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        participant_ids,
        {
            "event": "inbox_message_updated",
            "conversation_id": conversation.public_id,
            "message": message_payload,
        },
    )
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        participant_ids,
        {"event": "inbox_conversation_updated", "conversation_id": conversation.public_id},
    )
    return InboxMessageResponse(**message_payload)


@router.post("/conversations/{conversation_id}/messages/{message_id}/delete-for-me", response_model=InboxDeleteForMeResponse)
def delete_message_for_me(
    conversation_id: str,
    message_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    ok = inbox_preference_service.mark_message_deleted_for_user(db, conversation, current_user, message_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Message not found")
    return InboxDeleteForMeResponse()
