from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.support import TextModerationRequest
from app.services.ai_moderation_service import moderate_text


def check_room_text(db: Session, *, actor: User, room_id: str, text: str):
    return moderate_text(
        db,
        actor=actor,
        payload=TextModerationRequest(text=text, surface="room_chat", room_id=room_id),
    )
