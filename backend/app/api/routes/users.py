from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models.user import User
from app.schemas.user import PublicUserProfileResponse, UserMeResponse
from app.services import profile_service
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import get_primary_role, get_user_roles


router = APIRouter(prefix="/users", tags=["Users"])


def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header")

    token = authorization.replace("Bearer ", "").strip()

    payload = decode_access_token(token)

    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user_id = payload.get("sub")

    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token subject")

    user = db.query(User).filter(User.id == int(user_id)).first()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    if user.is_banned:
        raise HTTPException(status_code=403, detail="User is banned")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="User is inactive")

    return user


@router.get("/me", response_model=UserMeResponse)
def get_me(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user_roles = get_user_roles(current_user)
    roles = [role.value for role in user_roles]
    primary_role = get_primary_role(current_user)

    return UserMeResponse(
        id=current_user.id,
        public_user_id=current_user.public_user_id,
        display_custom_id=current_user.display_custom_id,
        username=current_user.username,
        display_name=current_user.display_name,
        avatar_url=current_user.avatar_url,
        roles=roles,
        primary_role=primary_role.value,
        primary_role_badge=get_primary_role_badge(primary_role),
        role_badges=get_role_badges(user_roles),
        vip=profile_service.vip_summary(db, current_user),
        wallet=profile_service.wallet_summary(db, current_user),
        is_active=current_user.is_active,
        is_banned=current_user.is_banned,
        last_device_id=current_user.last_device_id,
        last_login_at=current_user.last_login_at,
        last_seen_at=current_user.last_seen_at,
        created_at=current_user.created_at,
        updated_at=current_user.updated_at,
    )


@router.get("/public/{public_user_id}", response_model=PublicUserProfileResponse)
def get_public_profile(public_user_id: int, db: Session = Depends(get_db)):
    return PublicUserProfileResponse(**profile_service.public_profile_payload(db, public_user_id))
