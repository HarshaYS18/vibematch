from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.profile_display import CanonicalUserDisplayResponse
from app.services import profile_display_service

router = APIRouter(prefix="/profile-display", tags=["Profile Display"])


@router.get("/me", response_model=CanonicalUserDisplayResponse)
def get_my_profile_display(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return profile_display_service.canonical_user_display_payload(db, current_user, viewer=current_user)


@router.get("/users/{public_user_id}", response_model=CanonicalUserDisplayResponse)
def get_user_profile_display(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True)).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return profile_display_service.canonical_user_display_payload(db, user, viewer=current_user)
