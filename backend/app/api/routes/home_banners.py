from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.home_banner import HomeBannerCreateRequest, HomeBannerResponse
from app.services.home_banner_service import (
    create_home_banner,
    ensure_can_manage_home_banners,
    list_active_home_banners,
    list_manageable_home_banners,
    set_home_banner_active,
)

router = APIRouter(prefix="/home-banners", tags=["Home Banners"])


@router.get("", response_model=list[HomeBannerResponse])
def get_home_banners(
    placement: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    return list_active_home_banners(db=db, placement=placement)


@router.get("/manage", response_model=list[HomeBannerResponse])
def get_manageable_home_banners(
    placement: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ensure_can_manage_home_banners(current_user)
    return list_manageable_home_banners(db=db, placement=placement)


@router.post("", response_model=HomeBannerResponse)
def create_home_banner_route(
    payload: HomeBannerCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_home_banner(db=db, current_user=current_user, payload=payload)


@router.patch("/{banner_id}/active", response_model=HomeBannerResponse)
def update_home_banner_active(
    banner_id: int,
    is_active: bool,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return set_home_banner_active(db=db, current_user=current_user, banner_id=banner_id, is_active=is_active)
