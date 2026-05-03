from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models.user import User
from app.schemas.user import UserMeResponse, UserSearchResult
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


def _build_user_me_response(current_user: User) -> UserMeResponse:
    roles = [role.value for role in get_user_roles(current_user)]
    primary_role = get_primary_role(current_user).value

    return UserMeResponse(
        id=current_user.id,
        public_user_id=current_user.public_user_id,
        display_custom_id=current_user.display_custom_id,
        username=current_user.username,
        display_name=current_user.display_name,
        avatar_url=current_user.avatar_url,
        roles=roles,
        primary_role=primary_role,
        is_active=current_user.is_active,
        is_banned=current_user.is_banned,
        last_device_id=current_user.last_device_id,
        last_login_at=current_user.last_login_at,
        last_seen_at=current_user.last_seen_at,
        created_at=current_user.created_at,
        updated_at=current_user.updated_at,
    )


def _build_user_search_result(user: User) -> UserSearchResult:
    roles = [role.value for role in get_user_roles(user)]
    primary_role = get_primary_role(user).value

    return UserSearchResult(
        id=user.id,
        public_user_id=user.public_user_id,
        display_custom_id=user.display_custom_id,
        username=user.username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        roles=roles,
        primary_role=primary_role,
        is_active=user.is_active,
    )


@router.get("/me", response_model=UserMeResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return _build_user_me_response(current_user)


@router.get("/search", response_model=list[UserSearchResult])
def search_users(
    q: str = Query(min_length=1, max_length=80),
    limit: int = Query(default=20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query_text = q.strip()
    if not query_text:
        return []

    query = db.query(User).filter(User.is_active.is_(True), User.is_banned.is_(False))

    numeric_query = query_text.replace("#", "").strip()
    numeric_filters = []
    if numeric_query.isdigit():
        numeric_value = int(numeric_query)
        numeric_filters.extend(
            [
                User.public_user_id == numeric_value,
                User.display_custom_id == numeric_value,
            ]
        )

    like_query = f"%{query_text.lower()}%"
    text_filters = [
        User.username.ilike(like_query),
        User.display_name.ilike(like_query),
    ]

    results = (
        query.filter(or_(*(numeric_filters + text_filters)))
        .order_by(User.id.asc())
        .limit(limit)
        .all()
    )

    return [_build_user_search_result(user) for user in results]
