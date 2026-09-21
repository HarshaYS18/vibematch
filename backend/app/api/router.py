"""Canonical production API composition.

Every public HTTP/WebSocket endpoint is registered exactly once here. Route
modules own resource behavior; this module owns hierarchy and registration.
"""

from fastapi import APIRouter

from app.api.routes import (
    admin, admin_support, ai_moderation, app_source_registry, auth, calls,
    coin_sales, control_center, economy, economy_admin, economy_master,
    experience, families, families_economy, game_pool_admin, game_props_admin,
    game_settlements, games, games_master, gift_catalog, health, home_banners,
    inbox, inbox_ai, inbox_backup_google, inbox_calls, inbox_message_tools,
    inbox_preferences, inbox_stories, inbox_ws, love_bonds, lucky_coins,
    lucky_gifts, lucky_gift_admin, lucky_packets, media, media_control, media_realtime_auth, media_safety_admin,
    moderation, notifications, presence, profile_display, push, rankings,
    relationship_exp, role_badges, room_levels, room_music_media,
    room_realtime, room_realtime_commands, settings, social, super_owner,
    support, users, vibes, vip_admin, wallet,
)
from app.api.routes.rooms import cricket, rooms
from app.api.routes.store import router as store_router

api_router = APIRouter(prefix="/api/v1")

# System and identity.
for router in (
    health.router, auth.router, app_source_registry.router, users.router, support.router,
    settings.router, profile_display.router, role_badges.router,
):
    api_router.include_router(router)

# Social/content.
for router in (
    social.router, vibes.router, presence.router, notifications.router,
    push.router, love_bonds.router, relationship_exp.router, families.router,
    families_economy.router, home_banners.router, rankings.router,
):
    api_router.include_router(router)

# Rooms and realtime.
for router in (
    rooms.router, room_levels.router, cricket.router, room_realtime.router,
    room_realtime_commands.router, media_control.router, media_realtime_auth.router,
):
    api_router.include_router(router)

# Inbox parent and children.
api_router.include_router(inbox.router)
api_router.include_router(inbox_preferences.router, prefix="/inbox", tags=["Inbox"])
api_router.include_router(inbox_stories.router, prefix="/inbox", tags=["Inbox"])
api_router.include_router(inbox_message_tools.router, prefix="/inbox", tags=["Inbox"])
api_router.include_router(inbox_calls.router, prefix="/inbox", tags=["Inbox Calls"])
for router in (inbox_backup_google.router, inbox_ai.router, inbox_ws.router, calls.router):
    api_router.include_router(router)

# Media storage/upload.
api_router.include_router(media.router)
api_router.include_router(room_music_media.router)

# Economy, gifts, games and store.
for router in (
    wallet.router, economy.router, economy_master.router, gift_catalog.router,
    lucky_gifts.router, lucky_coins.router, games.router, games_master.router,
    game_settlements.router, store_router, coin_sales.router, experience.router,
):
    api_router.include_router(router)
api_router.include_router(lucky_packets.router)

# Administrative surfaces.
for router in (
    admin.router, admin_support.router, moderation.router, ai_moderation.router,
    media_safety_admin.router, vip_admin.router, super_owner.router,
    control_center.router, game_pool_admin.router, game_props_admin.router,
    economy_admin.router, games.admin_router, gift_catalog.admin_router,
    rooms.admin_router, coin_sales.admin_router, lucky_gift_admin.router,
    home_banners.admin_router, vibes.admin_router,
):
    api_router.include_router(router)
