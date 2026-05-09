from app.models.role import RoleName
from app.schemas.role_badge import RoleBadgeResponse


_ROLE_BADGE_MAP: dict[RoleName, RoleBadgeResponse] = {
    RoleName.FOUNDER_OWNER: RoleBadgeResponse(
        role=RoleName.FOUNDER_OWNER.value,
        display_title="Super Owner",
        badge_label="Head Official",
        pill_label="Super Owner · Head Official",
        group="official",
        priority=100,
        icon="workspace_premium",
        background_color="#2A1600",
        text_color="#FFD36A",
        border_color="#F4B63D",
        show_verified_tick=True,
    ),
    RoleName.OWNER: RoleBadgeResponse(
        role=RoleName.OWNER.value,
        display_title="Owner",
        badge_label="Official",
        pill_label="Owner · Official",
        group="official",
        priority=90,
        icon="verified",
        background_color="#24133A",
        text_color="#FFD36A",
        border_color="#C99A3B",
        show_verified_tick=True,
    ),
    RoleName.SUPERADMIN: RoleBadgeResponse(
        role=RoleName.SUPERADMIN.value,
        display_title="Super Admin",
        badge_label="Admin Official Lv1",
        pill_label="Super Admin · Admin Official Lv1",
        group="admin_official",
        priority=80,
        icon="admin_panel_settings",
        background_color="#1C233A",
        text_color="#9AD7FF",
        border_color="#4A9BFF",
    ),
    RoleName.ADMIN: RoleBadgeResponse(
        role=RoleName.ADMIN.value,
        display_title="Admin",
        badge_label="Admin Official Lv2",
        pill_label="Admin · Admin Official Lv2",
        group="admin_official",
        priority=70,
        icon="shield",
        background_color="#1B2630",
        text_color="#AEE9D8",
        border_color="#12C7B7",
    ),
    RoleName.MONITOR: RoleBadgeResponse(
        role=RoleName.MONITOR.value,
        display_title="Monitor",
        badge_label="Monitor Team",
        pill_label="Monitor · Safety Team",
        group="moderation",
        priority=60,
        icon="health_and_safety",
        background_color="#2C1725",
        text_color="#FF9CB3",
        border_color="#E84C72",
    ),
    RoleName.CS: RoleBadgeResponse(
        role=RoleName.CS.value,
        display_title="CS",
        badge_label="Support Official",
        pill_label="CS · Support Official",
        group="support",
        priority=55,
        icon="support_agent",
        background_color="#142633",
        text_color="#93E7FF",
        border_color="#18C7B7",
    ),
    RoleName.COIN_SELLER: RoleBadgeResponse(
        role=RoleName.COIN_SELLER.value,
        display_title="Coin Seller",
        badge_label="Coin Seller",
        pill_label="Coin Seller",
        group="business",
        priority=45,
        icon="paid",
        background_color="#2A1E0D",
        text_color="#FFD36A",
        border_color="#C99A3B",
    ),
    RoleName.MERCHANT: RoleBadgeResponse(
        role=RoleName.MERCHANT.value,
        display_title="Merchant",
        badge_label="Merchant",
        pill_label="Merchant",
        group="business",
        priority=44,
        icon="storefront",
        background_color="#231A30",
        text_color="#D7B8FF",
        border_color="#8C5CF6",
    ),
    RoleName.AGENCY_OWNER: RoleBadgeResponse(
        role=RoleName.AGENCY_OWNER.value,
        display_title="Agency Owner",
        badge_label="Agency Official",
        pill_label="Agency Owner · Agency Official",
        group="agency",
        priority=50,
        icon="groups",
        background_color="#112B25",
        text_color="#9EF2D3",
        border_color="#12C7B7",
    ),
    RoleName.BD: RoleBadgeResponse(
        role=RoleName.BD.value,
        display_title="BD",
        badge_label="Agency Official",
        pill_label="BD · Agency Official",
        group="agency",
        priority=46,
        icon="handshake",
        background_color="#112B25",
        text_color="#9EF2D3",
        border_color="#12C7B7",
    ),
    RoleName.RESELLER: RoleBadgeResponse(
        role=RoleName.RESELLER.value,
        display_title="Reseller",
        badge_label="Merchant",
        pill_label="Reseller · Merchant",
        group="business",
        priority=35,
        icon="storefront",
        background_color="#231A30",
        text_color="#D7B8FF",
        border_color="#8C5CF6",
    ),
}

_HOST_BADGE = RoleBadgeResponse(
    role="agency_member",
    display_title="Agency Member",
    badge_label="Host",
    pill_label="Agency Member · Host",
    group="agency",
    priority=30,
    icon="mic_external_on",
    background_color="#191B2F",
    text_color="#AAB6FF",
    border_color="#6D5DF6",
)


def get_role_badge(role: RoleName | str | None) -> RoleBadgeResponse | None:
    if role is None:
        return None

    if isinstance(role, str):
        normalized = role.strip().lower()
        if normalized in {"agency_member", "host"}:
            return _HOST_BADGE
        try:
            role = RoleName(normalized)
        except ValueError:
            return None

    return _ROLE_BADGE_MAP.get(role)


def get_role_badges(roles: list[RoleName]) -> list[RoleBadgeResponse]:
    badges = [badge for role in roles if (badge := get_role_badge(role)) is not None]
    return sorted(badges, key=lambda badge: badge.priority, reverse=True)


def get_primary_role_badge(role: RoleName | str | None) -> RoleBadgeResponse | None:
    return get_role_badge(role)
