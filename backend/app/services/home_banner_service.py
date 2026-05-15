from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.home_banner import HomeBanner, HomeBannerPlacement
from app.models.user import User
from app.schemas.home_banner import HomeBannerCreateRequest

_ALLOWED_PLACEMENTS = {item.value for item in HomeBannerPlacement}
_ALLOWED_TARGETS = {"event", "policy", "promo", "recharge", "external"}
_OWNER_ROLES = {"founder_owner", "owner", "super_owner", "banner_manager", "manage_home_banners"}


def _role_values(user: User) -> set[str]:
    values: set[str] = set()
    for role in getattr(user, "roles", []) or []:
        value = getattr(role, "role", None) or getattr(role, "name", None) or role
        values.add(value.value if hasattr(value, "value") else str(value))
    return values


def ensure_can_manage_home_banners(current_user: User) -> None:
    if not bool(_role_values(current_user) & _OWNER_ROLES):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only authorized officials can manage home banners")


def _clean_payload(payload: HomeBannerCreateRequest) -> None:
    if payload.placement not in _ALLOWED_PLACEMENTS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid banner placement")
    if payload.target not in _ALLOWED_TARGETS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid banner target")
    if payload.ends_at is not None and payload.starts_at is not None and payload.ends_at < payload.starts_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Banner end date cannot be before start date")
    if not payload.image_url.lower().startswith(("http://", "https://", "/static/")):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Banner image must be an uploaded/static/CDN URL")


def list_active_home_banners(db: Session, placement: str | None = None) -> list[HomeBanner]:
    now = datetime.utcnow()
    query = db.query(HomeBanner).filter(HomeBanner.is_active.is_(True))
    query = query.filter((HomeBanner.starts_at.is_(None)) | (HomeBanner.starts_at <= now))
    query = query.filter((HomeBanner.ends_at.is_(None)) | (HomeBanner.ends_at >= now))
    if placement:
        query = query.filter(HomeBanner.placement == placement)
    return query.order_by(HomeBanner.sort_order.asc(), HomeBanner.created_at.desc()).all()


def list_manageable_home_banners(db: Session, placement: str | None = None) -> list[HomeBanner]:
    query = db.query(HomeBanner)
    if placement:
        query = query.filter(HomeBanner.placement == placement)
    return query.order_by(HomeBanner.sort_order.asc(), HomeBanner.created_at.desc()).all()


def create_home_banner(db: Session, current_user: User, payload: HomeBannerCreateRequest) -> HomeBanner:
    ensure_can_manage_home_banners(current_user)
    _clean_payload(payload)
    banner = HomeBanner(
        placement=payload.placement,
        title=payload.title.strip(),
        image_url=payload.image_url.strip(),
        target=payload.target,
        target_url=payload.target_url.strip() if payload.target_url else None,
        description=payload.description.strip() if payload.description else None,
        sort_order=payload.sort_order,
        is_active=payload.is_active,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        created_by_user_id=current_user.id,
        updated_by_user_id=current_user.id,
    )
    db.add(banner)
    db.commit()
    db.refresh(banner)
    return banner


def set_home_banner_active(db: Session, current_user: User, banner_id: int, is_active: bool) -> HomeBanner:
    ensure_can_manage_home_banners(current_user)
    banner = db.query(HomeBanner).filter(HomeBanner.id == banner_id).first()
    if banner is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner not found")
    banner.is_active = is_active
    banner.updated_by_user_id = current_user.id
    banner.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(banner)
    return banner
