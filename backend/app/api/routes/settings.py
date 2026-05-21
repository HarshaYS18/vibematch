from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.follow import UserBlock
from app.models.user import User
from app.schemas.settings import BlockedUserResponse, UserAppSettingsResponse, UserAppSettingsUpdate
from app.services import user_settings_service

router = APIRouter(prefix="/settings", tags=["Settings"])


@router.get("/me", response_model=UserAppSettingsResponse)
def get_my_settings(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    row = user_settings_service.get_settings(db, user=current_user)
    return UserAppSettingsResponse(settings=row.settings_json, updated_at=row.updated_at)


@router.put("/me", response_model=UserAppSettingsResponse)
def update_my_settings(payload: UserAppSettingsUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    row = user_settings_service.update_settings(db, user=current_user, settings=payload.settings)
    return UserAppSettingsResponse(settings=row.settings_json, updated_at=row.updated_at)


@router.post("/me/reset", response_model=UserAppSettingsResponse)
def reset_my_settings(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    row = user_settings_service.reset_settings(db, user=current_user)
    return UserAppSettingsResponse(settings=row.settings_json, updated_at=row.updated_at)


@router.get("/blocked-users", response_model=list[BlockedUserResponse])
def list_blocked_users(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    rows = (
        db.query(UserBlock, User)
        .join(User, User.id == UserBlock.blocked_user_id)
        .filter(UserBlock.blocker_user_id == current_user.id)
        .order_by(UserBlock.created_at.desc())
        .all()
    )
    return [
        BlockedUserResponse(
            public_user_id=user.public_user_id,
            display_name=user.display_name or user.username or f"User {user.public_user_id}",
            username=user.username,
            avatar_url=user.avatar_url,
        )
        for _, user in rows
    ]


@router.delete("/blocked-users/{public_user_id}", response_model=list[BlockedUserResponse])
def unblock_user(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    target = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Blocked user not found.")
    row = db.query(UserBlock).filter(UserBlock.blocker_user_id == current_user.id, UserBlock.blocked_user_id == target.id).first()
    if row:
        db.delete(row)
        db.commit()
    return list_blocked_users(db=db, current_user=current_user)
