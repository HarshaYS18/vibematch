from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models import ProfileVisit
from app.models.cdn_media import CdnMediaType
from app.models.follow import UserBlock, UserFollow
from app.models.user import User
from app.schemas.profile_visit import ProfileVisitListResponse, ProfileVisitRecordResponse
from app.schemas.user import PublicUserProfileResponse, UserMeResponse, UserProfileUpdateRequest, UserRelationshipResponse, UserSearchResponse, UserSearchResultResponse
from app.services import cdn_media_service, profile_service
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import get_primary_role, get_user_roles
from app.services.user_master_state_service import get_user_master_state


router = APIRouter(prefix="/users", tags=["Users"])

_ALLOWED_GENDERS = {"male", "female", "other", "prefer_not_to_say"}
_ALLOWED_GENDER_PREFS = {"male", "female", "both"}
_ALLOWED_MARITAL = {"single", "married", "committed", "divorced"}
_ALLOWED_MARITAL_PREFS = {"any", "single", "married", "committed", "divorced"}


def get_current_user_from_token(db: Session, token: str) -> User:
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
    token_device_id = str(payload.get("device_id") or "").strip()
    active_device_id = (user.last_device_id or "").strip()
    if active_device_id and token_device_id != active_device_id:
        raise HTTPException(status_code=401, detail="Session replaced by a newer login")
    return user


def get_current_user(authorization: str | None = Header(default=None), db: Session = Depends(get_db)) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header")
    token = authorization.replace("Bearer ", "").strip()
    return get_current_user_from_token(db, token)


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


def _validate_profile_media_url(db: Session, *, user: User, url: str | None, media_type: CdnMediaType, label: str) -> str | None:
    cleaned = _clean_optional(url)
    if cleaned is None:
        return None
    try:
        cdn_media_service.assert_user_owns_active_media_url(db, user=user, public_url=cleaned, media_type=media_type)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid {label}: {exc}") from exc
    return cleaned


def _validate_cover_photo_urls(db: Session, *, user: User, urls: list[str]) -> list[str]:
    cleaned = _clean_url_list(urls)
    for url in cleaned:
        _validate_profile_media_url(db, user=user, url=url, media_type=CdnMediaType.COVER_PHOTO, label="cover photo")
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
        equipped_items=profile_service.equipped_items_summary(db, current_user),
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


def _has_follow(db: Session, follower_id: int, followed_id: int) -> bool:
    return db.query(UserFollow.id).filter(UserFollow.follower_user_id == follower_id, UserFollow.followed_user_id == followed_id).first() is not None


def _display_name(user: User) -> str:
    return user.display_name or user.username or f"User {user.public_user_id}"


def _relationship_payload(db: Session, profile_user: User, current_user: User | None) -> UserRelationshipResponse:
    is_following = False
    follows_me = False
    blocked_by_me = False
    blocked_me = False
    can_follow = True
    follow_block_reason = None
    if current_user is not None and current_user.id != profile_user.id:
        is_following = _has_follow(db, current_user.id, profile_user.id)
        follows_me = _has_follow(db, profile_user.id, current_user.id)
        blocked_by_me = _is_blocked(db, current_user.id, profile_user.id)
        blocked_me = _is_blocked(db, profile_user.id, current_user.id)
        can_follow = not blocked_me
        if blocked_me:
            follow_block_reason = f"{_display_name(profile_user)} doesn't allow you to follow."
    followers_count = db.query(func.count(UserFollow.id)).filter(UserFollow.followed_user_id == profile_user.id).scalar() or 0
    following_count = db.query(func.count(UserFollow.id)).filter(UserFollow.follower_user_id == profile_user.id).scalar() or 0
    return UserRelationshipResponse(public_user_id=profile_user.public_user_id, is_following=is_following, follows_me=follows_me, is_friend=is_following and follows_me, blocked_by_me=blocked_by_me, blocked_me=blocked_me, can_follow=can_follow, follow_block_reason=follow_block_reason, followers_count=followers_count, following_count=following_count)


def _search_result_payload(db: Session, user: User, current_user: User) -> UserSearchResultResponse:
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
    relationship = _relationship_payload(db, user, current_user)
    return UserSearchResultResponse(public_user_id=user.public_user_id, display_custom_id=user.display_custom_id, username=user.username, display_name=user.display_name, avatar_url=user.avatar_url, primary_role=primary_role.value, primary_role_badge=get_primary_role_badge(primary_role), role_badges=get_role_badges(user_roles), vip=profile_service.vip_summary(db, user), equipped_items=profile_service.equipped_items_summary(db, user), is_online=False, last_seen_at=user.last_seen_at, is_following=relationship.is_following, follows_me=relationship.follows_me, is_friend=relationship.is_friend, blocked_by_me=relationship.blocked_by_me, blocked_me=relationship.blocked_me, can_follow=relationship.can_follow)


def _get_public_active_user(db: Session, public_user_id: int) -> User:
    user = db.query(User).filter(or_(User.public_user_id == public_user_id, User.display_custom_id == public_user_id)).filter(User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def _profile_visit_payload(db: Session, visit: ProfileVisit) -> ProfileVisitRecordResponse:
    visitor = visit.visitor
    primary_role = get_primary_role(visitor)
    role_badge = get_primary_role_badge(primary_role)
    visible_id = visitor.display_custom_id or visitor.public_user_id
    return ProfileVisitRecordResponse(id=f"visitor_{visit.profile_owner_user_id}_{visit.visitor_user_id}", visitor_user_id=visitor.id, visitor_public_user_id=visitor.public_user_id, visitor_visible_id=str(visible_id), visitor_display_name=_display_name(visitor), visitor_username=visitor.username, visitor_avatar_url=visitor.avatar_url, visitor_role_label=role_badge.display_title, visited_at=visit.last_visited_at, visit_count=visit.visit_count)


def _record_profile_visit(db: Session, profile_owner: User, visitor: User, source: str = "public_profile") -> None:
    if profile_owner.id == visitor.id:
        return
    visit = db.query(ProfileVisit).filter(ProfileVisit.profile_owner_user_id == profile_owner.id, ProfileVisit.visitor_user_id == visitor.id).first()
    now = datetime.utcnow()
    if visit is None:
        visit = ProfileVisit(profile_owner_user_id=profile_owner.id, visitor_user_id=visitor.id, source=source, visit_count=1, first_visited_at=now, last_visited_at=now)
        db.add(visit)
    else:
        visit.visit_count += 1
        visit.source = source
        visit.last_visited_at = now
    db.commit()


@router.get("/me", response_model=UserMeResponse)
def get_me(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _user_me_response(db, current_user)


@router.get("/me/master-state")
def get_my_master_state(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return get_user_master_state(db, current_user)


@router.patch("/me/profile", response_model=UserMeResponse)
def update_my_profile(payload: UserProfileUpdateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if payload.display_name is not None:
        safe_name = payload.display_name.strip()
        if len(safe_name) < 2:
            raise HTTPException(status_code=400, detail="Display name must be at least 2 characters")
        current_user.display_name = safe_name
    if payload.bio is not None:
        current_user.bio = _clean_optional(payload.bio)
    if payload.avatar_url is not None:
        current_user.avatar_url = _validate_profile_media_url(db, user=current_user, url=payload.avatar_url, media_type=CdnMediaType.PROFILE_PICTURE, label="avatar")
    current_user.cover_photo_urls = _validate_cover_photo_urls(db, user=current_user, urls=payload.cover_photo_urls)
    current_user.date_of_birth = payload.date_of_birth
    current_user.gender = _clean_enum(payload.gender, _ALLOWED_GENDERS, "gender")
    current_user.profession = _clean_optional(payload.profession)
    current_user.marital_status = _clean_enum(payload.marital_status, _ALLOWED_MARITAL, "marital status")
    current_user.friend_gender_preference = _clean_enum(payload.friend_gender_preference, _ALLOWED_GENDER_PREFS, "friend gender preference")
    current_user.friend_marital_preference = _clean_enum(payload.friend_marital_preference, _ALLOWED_MARITAL_PREFS, "friend marital preference")
    current_user.interests = _clean_interests(payload.interests)
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return _user_me_response(db, current_user)


@router.get("/search", response_model=UserSearchResponse)
def search_users(q: str = Query(..., min_length=1, max_length=80), limit: int = Query(20, ge=1, le=50), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    query = q.strip()
    numeric = int(query) if query.isdigit() else None
    filters = [User.username.ilike(f"%{query}%"), User.display_name.ilike(f"%{query}%")]
    if numeric is not None:
        filters.append(User.public_user_id == numeric)
        filters.append(User.display_custom_id == numeric)
    users = db.query(User).filter(or_(*filters)).filter(User.is_active.is_(True), User.is_banned.is_(False)).limit(limit).all()
    return UserSearchResponse(results=[_search_result_payload(db, user, current_user) for user in users])


@router.get("/profile/{public_user_id}", response_model=PublicUserProfileResponse)
@router.get("/{public_user_id}", response_model=PublicUserProfileResponse)
def get_public_profile(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = _get_public_active_user(db, public_user_id)
    _record_profile_visit(db, user, current_user)
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
    return PublicUserProfileResponse(public_user_id=user.public_user_id, display_custom_id=user.display_custom_id, username=user.username, display_name=user.display_name, avatar_url=user.avatar_url, bio=user.bio, cover_photo_urls=user.cover_photo_urls or [], date_of_birth=user.date_of_birth, gender=user.gender, profession=user.profession, marital_status=user.marital_status, friend_gender_preference=user.friend_gender_preference, friend_marital_preference=user.friend_marital_preference, interests=user.interests or [], primary_role=primary_role.value, primary_role_badge=get_primary_role_badge(primary_role), role_badges=get_role_badges(user_roles), vip=profile_service.vip_summary(db, user), wallet=profile_service.wallet_summary(db, user, include_private_balances=False), equipped_items=profile_service.equipped_items_summary(db, user), is_online=False, relationship=_relationship_payload(db, user, current_user), last_seen_at=user.last_seen_at, created_at=user.created_at)


@router.get("/me/visitors", response_model=ProfileVisitListResponse)
@router.get("/me/profile-visitors", response_model=ProfileVisitListResponse)
def get_my_profile_visitors(limit: int = Query(20, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    visits = db.query(ProfileVisit).filter(ProfileVisit.profile_owner_user_id == current_user.id).order_by(ProfileVisit.last_visited_at.desc()).limit(limit).all()
    return ProfileVisitListResponse(visitors=[_profile_visit_payload(db, visit) for visit in visits])