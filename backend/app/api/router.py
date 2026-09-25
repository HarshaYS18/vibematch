"""Canonical production API composition.

Every public HTTP/WebSocket endpoint is registered exactly once here. Route
modules own resource behavior; this module owns hierarchy and registration.
"""

from fastapi import APIRouter

from app.api.routes import (
    admin_support, ai_moderation, app_source_registry, calls,
    control_center, economy, economy_admin, economy_master, economy_proxy,
    experience, families_economy, game_platform_proxy, game_props_admin,
    game_settlements, health, home_banners,
    identity_proxy, inbox_proxy, inbox_stories,
    lucky_gift_admin, media, media_control, media_realtime_auth, media_safety_admin, media_uploads_v2,
    notification_proxy, presence, profile_social_proxy, rankings, search_proxy,
    relationship_exp, role_badges, room_control_proxy, room_cross_domain,
    room_levels, room_music_media, realtime_gateway_auth, settings, super_owner,
    support, users, vibes_proxy, vip_admin, wallet,
)
from app.api.routes.rooms import cricket
from app.api.routes.store import router as store_router

api_router = APIRouter(prefix="/api/v1")

# System and identity.
for router in (
    health.router, identity_proxy.router, app_source_registry.router, users.router, support.router,
    settings.router, role_badges.router,
):
    api_router.include_router(router)

# Social/content.
for router in (
    vibes_proxy.router, presence.router, notification_proxy.router,
    relationship_exp.router, families_economy.router,
    home_banners.router, rankings.router, search_proxy.router,
):
    api_router.include_router(router)

# Identity and Profile/Social are separately deployed authorities. Public URLs
# remain stable through the core compatibility facade.
api_router.include_router(profile_social_proxy.router)

# Rooms and realtime. Cross-domain projections/commerce stay explicit in core
# and must be registered before the Room Control catch-all proxy.
for router in (
    room_levels.router, cricket.router, room_cross_domain.router,
    media_control.router, media_realtime_auth.router, realtime_gateway_auth.router,
    room_control_proxy.router,
):
    api_router.include_router(router)

# Stories remain on the social/core boundary until the Vibes/Profile chunks.
# Register the concrete route before the Inbox catch-all compatibility proxy.
api_router.include_router(inbox_stories.router, prefix="/inbox", tags=["Inbox Stories"])

# Inbox chat is a separately deployed durable authority. The core API retains
# only a compatibility proxy for local development/rollback.
api_router.include_router(inbox_proxy.router)

# Media storage/upload.
api_router.include_router(media.router)
api_router.include_router(media_uploads_v2.router)
api_router.include_router(room_music_media.router)

# Economy financial route families are extracted behind a compatibility proxy.
# Core keeps /wallets and /economy as read/orchestration facades. The concrete
# legacy /games financial facade is registered before the Game Platform
# catch-all and delegates every value mutation to Economy.
api_router.include_router(economy_proxy.router)
api_router.include_router(game_settlements.router)

# Game catalog, sessions, rounds, risk state, stats and rankings are owned by
# the separately deployed Game Platform service. Public URLs remain stable.
api_router.include_router(game_platform_proxy.router)

for router in (
    wallet.router, economy.router, economy_master.router,
    store_router, experience.router,
):
    api_router.include_router(router)

# Administrative surfaces.
for router in (
    admin_support.router, ai_moderation.router,
    media_safety_admin.router, vip_admin.router, super_owner.router,
    control_center.router, game_props_admin.router,
    economy_admin.router,
    room_control_proxy.admin_router, lucky_gift_admin.router,
    home_banners.admin_router, vibes_proxy.admin_router,
):
    api_router.include_router(router)

# Register the Game Platform admin catch-all after concrete /admin/games/props
# and Economy-owned /admin/games/pools routes so domain boundaries cannot be
# shadowed by the compatibility proxy.
api_router.include_router(game_platform_proxy.admin_router)
