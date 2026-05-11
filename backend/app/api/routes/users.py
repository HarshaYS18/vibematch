from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models.follow import UserFollow
from app.models.user import User
from app.schemas.user import PublicUserProfileResponse, UserMeResponse, UserRelationshipResponse, UserSearchResponse, UserSearchResultResponse
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


def _relationship_payload(db: Session, profile_user: User, current_user: User | None) -> UserRelationshipResponse:
    is_following = False
    follows_me = False
    if current_user is not None and current_user.id != profile_user.id:
        is_following = db.query(UserFollow.id).filter(
            UserFollow.follower_user_id == current_user.id,
            UserFollow.followed_user_id == profile_user.id,
        ).first() is not None
        follows_me = db.query(UserFollow.id).filter(
            UserFollow.follower_user_id == profile_user.id,
            UserFollow.followed_user_id == current_user.id,
        ).first() is not None

    followers_count = db.query(func.count(UserFollow.id)).filter(UserFollow.followed_user_id == profile_user.id).scalar() or 0
    following_count = db.query(func.count(UserFollow.id)).filter(UserFollow.follower_user_id == profile_user.id).scalar() or 0
    return UserRelationshipResponse(
        public_user_id=profile_user.public_user_id,
        is_following=is_following,
        follows_me=follows_me,
        is_friend=is_following and follows_me,
        followers_count=followers_count,
        following_count=following_count,
    )


def _search_result_payload(db: Session, user: User, current_user: User) -> UserSearchResultResponse:
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
    relationship = _relationship_payload(db, user, current_user)
    return UserSearchResultResponse(
        public_user_id=user.public_user_id,
        display_custom_id=user.display_custom_id,
        username=user.username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        primary_role=primary_role.value,
        primary_role_badge=get_primary_role_badge(primary_role),
        role_badges=get_role_badges(user_roles),
        vip=profile_service.vip_summary(db, user),
        is_online=False,
        last_seen_at=user.last_seen_at,
        is_following=relationship.is_following,
        follows_me=relationship.follows_me,
        is_friend=relationship.is_friend,
    )


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


@router.get("/search", response_model=UserSearchResponse)
def search_users(
    q: str = Query(min_length=1, max_length=80),
    limit: int = Query(default=20, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = q.strip()
    if not query:
        return UserSearchResponse(query=q, users=[])

    clean = query.lstrip("@").strip()
    public_id = int(clean) if clean.isdigit() else None
    like = f"%{clean}%"

    filters = [
        User.username.ilike(like),
        User.display_name.ilike(like),
        User.official_handle.ilike(like),
        User.official_handle.ilike(f"@{clean}"),
    ]
    if public_id is not None:
        filters.extend([User.public_user_id == public_id, User.display_custom_id == public_id])

    users = (
        db.query(User)
        .filter(
            User.is_active.is_(True),
            User.is_banned.is_(False),
            User.id != current_user.id,
            or_(*filters),
        )
        .order_by(User.last_login_at.desc().nullslast(), User.created_at.desc())
        .limit(limit)
        .all()
    )
    return UserSearchResponse(query=query, users=[_search_result_payload(db, user, current_user) for user in users])


@router.get("/public/{public_user_id}", response_model=PublicUserProfileResponse)
def get_public_profile(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    payload = profile_service.public_profile_payload(db, public_user_id)
    payload["relationship"] = _relationship_payload(db, user, current_user)
    return PublicUserProfileResponse(**payload)


@router.get("/{public_user_id}/relationship", response_model=UserRelationshipResponse)
def get_user_relationship(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _relationship_payload(db, user, current_user)


@router.post("/{public_user_id}/follow", response_model=UserRelationshipResponse)
def follow_user(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot follow yourself")
    existing = db.query(UserFollow).filter(UserFollow.follower_user_id == current_user.id, UserFollow.followed_user_id == user.id).first()
    if existing is None:
        db.add(UserFollow(follower_user_id=current_user.id, followed_user_id=user.id))
        db.commit()
    return _relationship_payload(db, user, current_user)


@router.delete("/{public_user_id}/follow", response_model=UserRelationshipResponse)
def unfollow_user(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    existing = db.query(UserFollow).filter(UserFollow.follower_user_id == current_user.id, UserFollow.followed_user_id == user.id).first()
    if existing is not None:
        db.delete(existing)
        db.commit()
    return _relationship_payload(db, user, current_user)
