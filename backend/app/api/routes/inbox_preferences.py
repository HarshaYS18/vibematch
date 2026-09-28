from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.inbox import InboxConversationResponse, InboxConversationThemeRequest, InboxPreferenceResponse, InboxPreferenceUpdateRequest
from app.services import inbox_preference_service, inbox_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(tags=["Inbox Preferences"])

@router.get("/preferences", response_model=InboxPreferenceResponse)
def get_preferences(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    pref = inbox_preference_service.get_preferences_read_only(db, current_user)
    return InboxPreferenceResponse(**inbox_preference_service.serialize_preferences(pref))

@router.patch("/preferences", response_model=InboxPreferenceResponse)
def update_preferences(request: InboxPreferenceUpdateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        pref = inbox_preference_service.update_preferences(
            db=db,
            user=current_user,
            strangers_can_message=request.strangers_can_message,
            strangers_can_mention_in_vibes=request.strangers_can_mention_in_vibes,
            read_receipts_enabled=request.read_receipts_enabled,
            online_visibility=request.online_visibility,
            last_seen_visibility=request.last_seen_visibility,
            typing_activity_visibility=request.typing_activity_visibility,
            story_visibility=request.story_visibility,
            device_unlock_enabled=request.device_unlock_enabled,
            default_chat_theme=request.default_chat_theme,
            default_wallpaper_key=request.default_wallpaper_key,
            default_wallpaper_url=request.default_wallpaper_url,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxPreferenceResponse(**inbox_preference_service.serialize_preferences(pref))

@router.patch("/conversations/{conversation_id}/theme", response_model=InboxConversationResponse)
def update_conversation_theme(
    conversation_id: str,
    request: InboxConversationThemeRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    try:
        inbox_preference_service.update_conversation_theme(db=db, conversation=conversation, user=current_user, chat_theme=request.chat_theme, wallpaper_key=request.wallpaper_key, wallpaper_url=request.wallpaper_url)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    background_tasks.add_task(
        inbox_ws_manager.send_to_user,
        current_user.id,
        {
            "event": "inbox_conversation_updated",
            "conversation_id": conversation.public_id,
        },
    )
    payload = inbox_service.conversation_to_dict(conversation, current_user, db=db)
    payload.update(inbox_preference_service.conversation_theme_payload(db, conversation, current_user))
    return InboxConversationResponse(**payload)
