from fastapi import APIRouter

from app.models.role import RoleName
from app.schemas.role_badge import RoleBadgeResponse
from app.services.role_badge_service import get_role_badge


router = APIRouter(prefix="/roles", tags=["Roles"])


@router.get("/badges", response_model=list[RoleBadgeResponse])
def list_role_badges():
    roles = [
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
        RoleName.SUPERADMIN,
        RoleName.ADMIN,
        RoleName.MONITOR,
        RoleName.CS,
        RoleName.AGENCY_OWNER,
        RoleName.BD,
        RoleName.COIN_SELLER,
        RoleName.MERCHANT,
        RoleName.RESELLER,
    ]
    badges = [badge for role in roles if (badge := get_role_badge(role)) is not None]
    host_badge = get_role_badge("agency_member")
    if host_badge is not None:
        badges.append(host_badge)
    return sorted(badges, key=lambda badge: badge.priority, reverse=True)


@router.get("/badges/{role}", response_model=RoleBadgeResponse)
def get_role_badge_by_role(role: str):
    badge = get_role_badge(role)
    if badge is None:
        return RoleBadgeResponse(
            role="user",
            display_title="User",
            badge_label="Member",
            pill_label="Member",
            group="user",
            priority=0,
            icon="person",
            background_color="#F7F1EA",
            text_color="#6E6078",
            border_color="#E6D9CE",
            show_verified_tick=False,
        )
    return badge
