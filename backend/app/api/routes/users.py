from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models.follow import UserBlock, UserFollow
from app.models.user import User
from app.schemas.user import PublicUserProfileResponse, UserMeResponse, UserProfileUpdateRequest, UserRelationshipResponse, UserSearchResponse, UserSearchResultResponse
from app.services import profile_service
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import get_primary_role, get_user_roles


router = APIRouter(prefix="/users", tags=["Users"])

_ALLOWED_GENDERS = {"male", "female", "other", "prefer_not_to_say"}
_ALLOWED_GENDER_PREFS = {"male", "female", "both"}
_ALLOWED_MARITAL = {"single", "married", "committed", "divorced"}
_ALLOWED_MARITAL_PREFS = {"any", "single", "married", "committed", "divorced"}


def get_current_user(authorization: str | None = Header(default=None), db: Session = Depends(get_db)) -> User:
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


def _clean_optional(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip()
    return text or None


def _clean_url_list(values: list[str]) -> list[str]:
    cleaned: list[str] = []
    seen: set[str] = set()
    for raw in values:
        item = raw.strip()
        if not item or item in seen:
            continue
        if len(item) > 500:
            raise HTTPException(status_code=400, detail="Cover photo URL is too long")
        seen.add(item)
        cleaned.append(item)
    if len(cleaned) > 6:
        raise HTTPException(status_code=400, detail="Maximum 6 cover photos allowed")
    return cleaned


def _clean_enum(value: str | None, allowed: set[str], field_name: str) -> str | None:
    cleaned = _clean_optional(value)
    if cleaned is None:
        return None
    normalized = cleaned.lower().replace(" ", "_").replace("-", "_")
    if normalized not in allowed:
        raise HTTPException(status_code=400, detail=f"Invalid {field_name}")
    return normalized


def _clean_interests(values: list[str]) -> list[str]:
    cleaned: list[str] = []
    seen: set[str] = set()
    for raw in values:
        item = raw.strip()
        key = item.lower()
        if not item or key in seen:
            continue
        if len(item) > 40:
            raise HTTPException(status_code=400, detail="Interest is too long")
        seen.add(key)
        cleaned.append(item)
    if len(cleaned) > 40:
        raise HTTPException(status_code=400, detail="Too many interests")
    return cleaned


def _user_me_response(db: Session, current_user: User) -> UserMeResponse:
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
        bio=current_user.bio,
        cover_photo_urls=current_user.cover_photo_urls or [],
        date_of_birth=current_user.date_of_birth,
        gender=current_user.gender,
        profession=current_user.profession,
        marital_status=current_user.marital_status,
        friend_gender_preference=current_user.friend_gender_preference,
        friend_marital_preference=current_user.friend_marital_preference,
        interests=current_user.interests or [],
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


def _is_blocked(db: Session, blocker_id: int, blocked_id: int) -> bool:
    return db.query(UserBlock.id).filter(UserBlock.blocker_user_id == blocker_id, UserBlock.blocked_user_id == blocked_id).first() is not None


def _relationship_payload(db: Session, profile_user: User, current_user: User | None) -> UserRelationshipResponse:
    is_following = False
    follows_me = False
    blocked_by_me = False
    blocked_me = False
    can_follow = True
    follow_block_reason = None
    if current_user is not None and current_user.id != profile_user.id:
        is_following = db.query(UserFollow.id).filter(UserFollow.follower_user_id == current_user.id, UserFollow.followed_user_id == profile_user.id).first() is not None
        follows_me = db.query(UserFollow.id).filter(UserFollow.follower_user_id == profile_user.id, UserFollow.followed_user_id == current_user.id).first() is not None
        blocked_by_me = _is_blocked(db, current_user.id, profile_user.id)
        blocked_me = _is_blocked(db, profile_user.id, current_user.id)
        can_follow = not blocked_by_me and not blocked_me
        if blocked_by_me:
            follow_block_reason = "Unblock this user before following them."
        elif blocked_me:
            follow_block_reason = f"{profile_user.display_name or profile_user.username or 'This user'} doesn't allow you to follow them."
    followers_count = db.query(func.count(UserFollow.id)).filter(UserFollow.followed_user_id == profile_user.id).scalar() or 0
    following_count = db.query(func.count(UserFollow.id)).filter(UserFollow.follower_user_id == profile_user.id).scalar() or 0
    return UserRelationshipResponse(public_user_id=profile_user.public_user_id, is_following=is_following, follows_me=follows_me, is_friend=is_following and follows_me, blocked_by_me=blocked_by_me, blocked_me=blocked_me, can_follow=can_follow, follow_block_reason=follow_block_reason, followers_count=followers_count, following_count=following_count)


def _search_result_payload(db: Session, user: User, current_user: User) -> UserSearchResultResponse:
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
    relationship = _relationship_payload(db, user, current_user)
    return UserSearchResultResponse(public_user_id=user.public_user_id, display_custom_id=user.display_custom_id, username=user.username, display_name=user.display_name, avatar_url=user.avatar_url, primary_role=primary_role.value, primary_role_badge=get_primary_role_badge(primary_role), role_badges=get_role_badges(user_roles), vip=profile_service.vip_summary(db, user), is_online=False, last_seen_at=user.last_seen_at, is_following=relationship.is_following, follows_me=relationship.follows_me, is_friend=relationship.is_friend, blocked_by_me=relationship.blocked_by_me, blocked_me=relationship.blocked_me, can_follow=relationship.can_follow)


@router.get("/me", response_model=UserMeResponse)
def get_me(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _user_me_response(db, current_user)


@router.patch("/me/profile", response_model=UserMeResponse)
def update_my_profile(payload: UserProfileUpdateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if payload.display_name is not None:
        safe_name = payload.display_name.strip()
        if not safe_name:
            raise HTTPException(status_code=400, detail="Name is required")
        current_user.display_name = safe_name
    if payload.bio is not None:
        current_user.bio = _clean_optional(payload.bio)
    if payload.avatar_url is not None:
        current_user.avatar_url = _clean_optional(payload.avatar_url)
    current_user.cover_photo_urls = _clean_url_list(payload.cover_photo_urls)
    current_user.date_of_birth = payload.date_of_birth
    current_user.gender = _clean_enum(payload.gender, _ALLOWED_GENDERS, "gender")
    current_user.profession = _clean_optional(payload.profession)
    current_user.marital_status = _clean_enum(payload.marital_status, _ALLOWED_MARITAL, "marital status")
    current_user.friend_gender_preference = _clean_enum(payload.friend_gender_preference, _ALLOWED_GENDER_PREFS, "friend gender preference")
    current_user.friend_marital_preference = _clean_enum(payload.friend_marital_preference, _ALLOWED_MARITAL_PREFS, "friend marital preference")
    current_user.interests = _clean_interests(payload.interests)
    current_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(current_user)
    return _user_me_response(db, current_user)


@router.get("/search", response_model=UserSearchResponse)
def search_users(q: str = Query(min_length=1, max_length=80), limit: int = Query(default=20, ge=1, le=50), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    query = q.strip()
    if not query:
        return UserSearchResponse(query=q, users=[])
    clean = query.lstrip("@").strip()
    public_id = int(clean) if clean.isdigit() else None
    like = f"%{clean}%"
    filters = [User.username.ilike(like), User.display_name.ilike(like), User.official_handle.ilike(like), User.official_handle.ilike(f"@{clean}")]
    if public_id is not None:
        filters.extend([User.public_user_id == public_id, User.display_custom_id == public_id])
    users = db.query(User).filter(User.is_active.is_(True), User.is_banned.is_(False), User.id != current_user.id, or_(*filters)).order_by(User.last_login_at.desc().nullslast(), User.created_at.desc()).limit(limit).all()
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
    relationship = _relationship_payload(db, user, current_user)
    if not relationship.can_follow:
        raise HTTPException(status_code=403, detail=relationship.follow_block_reason or "This user doesn't allow you to follow them.")
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


@router.post("/{public_user_id}/block", response_model=UserRelationshipResponse)
def block_user(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot block yourself")
    existing = db.query(UserBlock).filter(UserBlock.blocker_user_id == current_user.id, UserBlock.blocked_user_id == user.id).first()
    if existing is None:
        db.add(UserBlock(blocker_user_id=current_user.id, blocked_user_id=user.id))
    db.query(UserFollow).filter(or_((UserFollow.follower_user_id == current_user.id) & (UserFollow.followed_user_id == user.id), (UserFollow.follower_user_id == user.id) & (UserFollow.followed_user_id == current_user.id))).delete(synchronize_session=False)
    db.commit()
    return _relationship_payload(db, user, current_user)


@router.delete("/{public_user_id}/block", response_model=UserRelationshipResponse)
def unblock_user(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    existing = db.query(UserBlock).filter(UserBlock.blocker_user_id == current_user.id, UserBlock.blocked_user_id == user.id).first()
    if existing is not None:
        db.delete(existing)
        db.commit()
    return _relationship_payload(db, user, current_user)
