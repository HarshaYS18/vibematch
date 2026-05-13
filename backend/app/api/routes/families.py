from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User

router = APIRouter(prefix="/families", tags=["Families"])


class FamilyPublicResponse(BaseModel):
    public_user_id: int
    id: int | None = None
    name: str | None = None
    family_name: str | None = None
    role: str | None = None
    level: int = 0
    member_count: int = 0
    total_exp: int = 0
    owner_public_user_id: int | None = None
    should_show: bool = False


def _empty_family(user: User) -> FamilyPublicResponse:
    return FamilyPublicResponse(
        public_user_id=user.public_user_id,
        id=None,
        name=None,
        family_name=None,
        role=None,
        level=0,
        member_count=0,
        total_exp=0,
        owner_public_user_id=None,
        should_show=False,
    )


@router.get("/me", response_model=FamilyPublicResponse)
def get_my_family(current_user: User = Depends(get_current_user)):
    return _empty_family(current_user)


@router.get("/public/{public_user_id}", response_model=FamilyPublicResponse)
def get_public_family(public_user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _empty_family(user)
