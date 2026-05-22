from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.support import ImageModerationRequest, ModerationResponse, TextModerationRequest
from app.services import ai_moderation_service

router = APIRouter(prefix="/ai-moderation", tags=["AI Moderation"])


@router.post("/text", response_model=ModerationResponse)
def moderate_text(payload: TextModerationRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return ai_moderation_service.moderate_text(db, actor=current_user, payload=payload)


@router.post("/image", response_model=ModerationResponse)
def moderate_image(payload: ImageModerationRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return ai_moderation_service.moderate_image(db, actor=current_user, payload=payload)
