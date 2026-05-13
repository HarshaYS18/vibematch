from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.services.role_service import get_primary_role, get_user_roles

router = APIRouter(tags=["Public Profile"])

class PublicUserResponse(BaseModel):
    id: int
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    primary_role: str
    roles: list[str]
    is_active: bool
    is_banned: bool
    last_seen_at: datetime | None = None
    created_at: datetime

class ProfileVisitorResponse(BaseModel):
    public_user_id: int
    display_name: str
    avatar_url: str | None = None
    visited_at: datetime

class VibeItemResponse(BaseModel):
    id: str
    public_user_id: int
    type: str
    caption: str
    media_url: str | None = None
    like_count: int = 0
    comment_count: int = 0
    created_at: datetime

class FamilyPublicResponse(BaseModel):
    public_user_id: int
    family_name: str | None = None
    role: str | None = None
    member_count: int = 0

class LoveBondPublicResponse(BaseModel):
    public_user_id: int
    bond_name: str | None = None
    partner_public_user_id: int | None = None
    level: int = 0


def _roles(user: User) -> list[str]:
    return [role.value for role in get_user_roles(user)]


def _find_user(db: Session, public_user_id: int) -> User:
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("/users/public/{public_user_id}", response_model=PublicUserResponse)
def get_public_user(public_user_id: int, db: Session = Depends(get_db)):
    user = _find_user(db, public_user_id)
    return PublicUserResponse(
        id=user.id,
        public_user_id=user.public_user_id,
        display_custom_id=user.display_custom_id,
        username=user.username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        primary_role=get_primary_role(user).value,
        roles=_roles(user),
        is_active=user.is_active,
        is_banned=user.is_banned,
        last_seen_at=user.last_seen_at,
        created_at=user.created_at,
    )


@router.get("/users/me/visitors", response_model=list[ProfileVisitorResponse])
def get_my_profile_visitors(
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
):
    return [
        ProfileVisitorResponse(
            public_user_id=current_user.public_user_id,
            display_name=current_user.display_name or current_user.username or "You",
            avatar_url=current_user.avatar_url,
            visited_at=current_user.last_seen_at or current_user.updated_at,
        )
    ][:limit]


@router.get("/vibes/user/{public_user_id}", response_model=list[VibeItemResponse])
def get_user_vibes(public_user_id: int, limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db)):
    user = _find_user(db, public_user_id)
    now = datetime.utcnow()
    return [
        VibeItemResponse(
            id=f"vibe_{user.public_user_id}_welcome",
            public_user_id=user.public_user_id,
            type="text",
            caption="Welcome to my Vibes",
            media_url=None,
            like_count=0,
            comment_count=0,
            created_at=now,
        )
    ][:limit]


@router.get("/families/public/{public_user_id}", response_model=FamilyPublicResponse)
def get_public_family(public_user_id: int, db: Session = Depends(get_db)):
    user = _find_user(db, public_user_id)
    return FamilyPublicResponse(public_user_id=user.public_user_id, family_name=None, role=None, member_count=0)


@router.get("/love-bonds/public/{public_user_id}", response_model=LoveBondPublicResponse)
def get_public_love_bond(public_user_id: int, db: Session = Depends(get_db)):
    user = _find_user(db, public_user_id)
    return LoveBondPublicResponse(public_user_id=user.public_user_id, bond_name=None, partner_public_user_id=None, level=0)
