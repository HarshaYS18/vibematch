from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api.routes import (
    admin,
    app_source_registry,
    auth,
    calls,
    coin_sales,
    control_center,
    economy,
    economy_admin,
    economy_gift_public,
    economy_master,
    experience,
    experience_room_public,
    families,
    families_economy,
    game_pool_admin,
    game_props_admin,
    game_settlements,
    games,
    games_master,
    gift_catalog,
    home_banners,
    inbox,
    inbox_backup_google,
    inbox_ws,
    internal_test,
    love_bonds,
    lucky_coins,
    lucky_gifts,
    media,
    media_realtime_auth,
    media_safety_admin,
    moderation,
    mvp_core,
    mvp_economy,
    mvp_operations,
    mvp_room_modes,
    mvp_social,
    notifications,
    presence,
    profile_display,
    push,
    rankings,
    relationship_exp,
    role_badges,
    room_levels,
    room_music_media,
    room_realtime,
    room_realtime_commands,
    social,
    super_owner,
    users,
    vibes,
    vip_admin,
    wallet,
)
from app.api.routes.rooms import cricket, rooms
from app.api.routes.store import router as store_router
from app.database import Base, engine
from app.models import (
    AdminLog,
    AuthIdentity,
    CallParticipant,
    CallSession,
    CdnMediaAsset,
    CoinPoolLedger,
    CoinSaleOrder,
    CoinSupplyPool,
    EconomyRuleLevel,
    EconomyRuleSet,
    CricketMatch,
    CricketTournament,
    DeviceBan,
    GameBet,
    GameDefinition,
    GamePool,
    GamePoolLedger,
    GameRiskAudit,
    GameRound,
    GameRoundPlayer,
    GiftCatalogCategory,
    GiftCatalogItem,
    GiftTransaction,
    InboxBackupJob,
    InboxBackupSetting,
    InboxConversation,
    InboxConversationUserSetting,
    InboxLockOtp,
    InboxLockSetting,
    InboxMessage,
    InboxMessageUserState,
    InboxParticipant,
    InboxReport,
    InboxStory,
    InboxStoryView,
    InboxUserPreference,
    LoveBond,
    LoveBondInventory,
    LoveBondRequest,
    MediaSafetySetting,
    MvpFeatureState,
    ProfileVisit,
    ProfileDisplayAudit,
    PushDeviceToken,
    Room,
    RoomChatMessage,
    RoomExperienceStatus,
    RoomRealtimeEvent,
    RoomSeatState,
    RubyWithdrawRequest,
    SpecialPermission,
    StoreItem,
    StoreAssetManifest,
    StoreCategory,
    User,
    UserBan,
    UserBlock,
    UserExperienceStatus,
    UserFollow,
    UserNotification,
    UserRoomPresence,
    UserRole,
    UserStoreInventory,
    UserStealthState,
    UserVipStatus,
    VibeComment,
    VibePost,
    VibeReaction,
    VibeReport,
    VibeShare,
    WalletLedger,
)

STATIC_DIR = Path("static")
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "uploads").mkdir(parents=True, exist_ok=True)

Base.metadata.create_all(bind=engine)


def _ensure_runtime_schema() -> None:
    """Small dev/beta schema guard for existing local Postgres tables.

    create_all creates new tables but does not add columns to existing tables.
    This keeps local closed-beta testing from crashing when fields are
    introduced before a formal Alembic migration pipeline is added.
    """
    statements = [
        "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS lock_password_hash VARCHAR(255)",
        "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS lock_updated_at TIMESTAMP",
        "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS lock_updated_by_user_id INTEGER",
        "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS seat_layout_id VARCHAR(24) DEFAULT '5x2' NOT NULL",
        "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS room_images_enabled BOOLEAN DEFAULT true NOT NULL",
        "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS guest_messages_enabled BOOLEAN DEFAULT true NOT NULL",
        "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS apply_only_mode_enabled BOOLEAN DEFAULT false NOT NULL",
        "UPDATE rooms SET room_images_enabled = true WHERE room_images_enabled IS NULL",
        "UPDATE rooms SET guest_messages_enabled = true WHERE guest_messages_enabled IS NULL",
        "UPDATE rooms SET apply_only_mode_enabled = false WHERE apply_only_mode_enabled IS NULL",
        "ALTER TABLE user_room_presence DROP CONSTRAINT IF EXISTS uq_user_one_active_room_presence",
        "ALTER TABLE room_participants ADD COLUMN IF NOT EXISTS is_stealth BOOLEAN DEFAULT false NOT NULL",
        "ALTER TABLE room_participants ADD COLUMN IF NOT EXISTS visible_in_online_count BOOLEAN DEFAULT true NOT NULL",
        "ALTER TABLE room_participants ADD COLUMN IF NOT EXISTS visible_in_user_list BOOLEAN DEFAULT true NOT NULL",
        "ALTER TABLE room_participants ADD COLUMN IF NOT EXISTS visible_to_public BOOLEAN DEFAULT true NOT NULL",
        "UPDATE room_participants SET is_stealth = false WHERE is_stealth IS NULL",
        "UPDATE room_participants SET visible_in_online_count = true WHERE visible_in_online_count IS NULL",
        "UPDATE room_participants SET visible_in_user_list = true WHERE visible_in_user_list IS NULL",
        "UPDATE room_participants SET visible_to_public = true WHERE visible_to_public IS NULL",
        "ALTER TABLE gift_catalog_items ADD COLUMN IF NOT EXISTS min_combo INTEGER DEFAULT 1 NOT NULL",
        "ALTER TABLE gift_catalog_items ADD COLUMN IF NOT EXISTS max_combo INTEGER DEFAULT 999 NOT NULL",
        "ALTER TABLE gift_catalog_items ADD COLUMN IF NOT EXISTS display_mode VARCHAR(40) DEFAULT 'normal' NOT NULL",
        "UPDATE gift_catalog_items SET min_combo = 1 WHERE min_combo IS NULL OR min_combo < 1",
        "UPDATE gift_catalog_items SET max_combo = 999 WHERE max_combo IS NULL OR max_combo < min_combo",
        "UPDATE gift_catalog_items SET display_mode = 'normal' WHERE display_mode IS NULL OR display_mode = ''",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS item_type VARCHAR(60) DEFAULT 'store_item' NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS currency_type VARCHAR(30) DEFAULT 'coin' NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS ownership_type VARCHAR(40) DEFAULT 'permanent' NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS duration_days INTEGER",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS cdn_asset_url VARCHAR(700)",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS thumbnail_url VARCHAR(700)",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS animation_url VARCHAR(700)",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS video_url VARCHAR(700)",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS visibility VARCHAR(40) DEFAULT 'public' NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS vip_required_level INTEGER DEFAULT 0 NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS svip_required_level INTEGER DEFAULT 0 NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS official_only BOOLEAN DEFAULT false NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS availability_starts_at TIMESTAMP",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS availability_ends_at TIMESTAMP",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS asset_version INTEGER DEFAULT 1 NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS cache_key VARCHAR(120)",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS catalog_version INTEGER DEFAULT 1 NOT NULL",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS metadata_json JSON",
        "ALTER TABLE store_items ADD COLUMN IF NOT EXISTS admin_notes TEXT",
        "ALTER TABLE user_store_inventory ADD COLUMN IF NOT EXISTS ownership_type VARCHAR(40) DEFAULT 'purchase' NOT NULL",
        "ALTER TABLE user_store_inventory ADD COLUMN IF NOT EXISTS granted_by_user_id INTEGER",
        "CREATE TABLE IF NOT EXISTS push_device_tokens (id SERIAL PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), device_id VARCHAR(180) NOT NULL, platform VARCHAR(40) NOT NULL, fcm_token VARCHAR(700) UNIQUE NOT NULL, app_package VARCHAR(180), is_active BOOLEAN DEFAULT true NOT NULL, last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
        "CREATE INDEX IF NOT EXISTS ix_push_device_tokens_user_id ON push_device_tokens(user_id)",
        "CREATE INDEX IF NOT EXISTS ix_push_device_tokens_device_id ON push_device_tokens(device_id)",
        "CREATE INDEX IF NOT EXISTS ix_push_device_tokens_fcm_token ON push_device_tokens(fcm_token)",
        "CREATE TABLE IF NOT EXISTS inbox_user_preferences (id SERIAL PRIMARY KEY, user_id INTEGER NOT NULL UNIQUE REFERENCES users(id), strangers_can_message BOOLEAN DEFAULT true NOT NULL, strangers_can_mention_in_vibes BOOLEAN DEFAULT true NOT NULL, read_receipts_enabled BOOLEAN DEFAULT true NOT NULL, online_visibility VARCHAR(40) DEFAULT 'everyone' NOT NULL, last_seen_visibility VARCHAR(40) DEFAULT 'everyone' NOT NULL, typing_activity_visibility VARCHAR(40) DEFAULT 'everyone' NOT NULL, story_visibility VARCHAR(40) DEFAULT 'friends' NOT NULL, device_unlock_enabled BOOLEAN DEFAULT false NOT NULL, default_chat_theme VARCHAR(80) DEFAULT 'pearl' NOT NULL, default_wallpaper_key VARCHAR(120) DEFAULT 'premium_pearl' NOT NULL, default_wallpaper_url VARCHAR(700), metadata_json JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
        "CREATE INDEX IF NOT EXISTS ix_inbox_user_preferences_user_id ON inbox_user_preferences(user_id)",
        "CREATE TABLE IF NOT EXISTS inbox_conversation_user_settings (id SERIAL PRIMARY KEY, conversation_id INTEGER NOT NULL REFERENCES inbox_conversations(id), user_id INTEGER NOT NULL REFERENCES users(id), is_locked BOOLEAN DEFAULT false NOT NULL, is_muted BOOLEAN DEFAULT false NOT NULL, is_pinned BOOLEAN DEFAULT false NOT NULL, is_archived BOOLEAN DEFAULT false NOT NULL, chat_theme VARCHAR(80), wallpaper_key VARCHAR(120), wallpaper_url VARCHAR(700), metadata_json JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(conversation_id, user_id))",
        "CREATE INDEX IF NOT EXISTS ix_inbox_conversation_user_settings_conversation_id ON inbox_conversation_user_settings(conversation_id)",
        "CREATE INDEX IF NOT EXISTS ix_inbox_conversation_user_settings_user_id ON inbox_conversation_user_settings(user_id)",
        "CREATE TABLE IF NOT EXISTS inbox_message_user_states (id SERIAL PRIMARY KEY, message_id INTEGER NOT NULL REFERENCES inbox_messages(id), user_id INTEGER NOT NULL REFERENCES users(id), is_deleted_for_me BOOLEAN DEFAULT false NOT NULL, is_starred BOOLEAN DEFAULT false NOT NULL, reaction VARCHAR(32), metadata_json JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(message_id, user_id))",
        "CREATE INDEX IF NOT EXISTS ix_inbox_message_user_states_message_id ON inbox_message_user_states(message_id)",
        "CREATE INDEX IF NOT EXISTS ix_inbox_message_user_states_user_id ON inbox_message_user_states(user_id)",
        "CREATE TABLE IF NOT EXISTS inbox_stories (id SERIAL PRIMARY KEY, public_id VARCHAR(80) UNIQUE NOT NULL, user_id INTEGER NOT NULL REFERENCES users(id), media_type VARCHAR(40) NOT NULL, media_url VARCHAR(700) NOT NULL, caption TEXT, visibility VARCHAR(40) DEFAULT 'friends' NOT NULL, metadata_json JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, expires_at TIMESTAMP NOT NULL, deleted_at TIMESTAMP)",
        "CREATE INDEX IF NOT EXISTS ix_inbox_stories_public_id ON inbox_stories(public_id)",
        "CREATE INDEX IF NOT EXISTS ix_inbox_stories_user_id ON inbox_stories(user_id)",
        "CREATE INDEX IF NOT EXISTS ix_inbox_stories_expires_at ON inbox_stories(expires_at)",
        "CREATE TABLE IF NOT EXISTS inbox_story_views (id SERIAL PRIMARY KEY, story_id INTEGER NOT NULL REFERENCES inbox_stories(id), viewer_user_id INTEGER NOT NULL REFERENCES users(id), viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(story_id, viewer_user_id))",
        "CREATE INDEX IF NOT EXISTS ix_inbox_story_views_story_id ON inbox_story_views(story_id)",
        "CREATE INDEX IF NOT EXISTS ix_inbox_story_views_viewer_user_id ON inbox_story_views(viewer_user_id)",
        "ALTER TABLE inbox_conversations ADD COLUMN IF NOT EXISTS metadata_json JSON",
        "ALTER TABLE inbox_messages ADD COLUMN IF NOT EXISTS metadata_json JSON",
        "ALTER TABLE inbox_messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMP",
        "ALTER TABLE inbox_messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS conversation_id INTEGER REFERENCES inbox_conversations(id)",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS room_public_id VARCHAR(32)",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS is_video_enabled BOOLEAN DEFAULT false NOT NULL",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS is_group_call BOOLEAN DEFAULT false NOT NULL",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS answered_at TIMESTAMP",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS ended_at TIMESTAMP",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS duration_seconds INTEGER",
        "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS end_reason VARCHAR(120)",
        "CREATE INDEX IF NOT EXISTS ix_call_sessions_conversation_id ON call_sessions(conversation_id)",
        "CREATE INDEX IF NOT EXISTS ix_call_sessions_room_public_id ON call_sessions(room_public_id)",
        "CREATE INDEX IF NOT EXISTS ix_call_sessions_status ON call_sessions(status)",
        "CREATE TABLE IF NOT EXISTS call_participants (id SERIAL PRIMARY KEY, call_session_id INTEGER NOT NULL REFERENCES call_sessions(id), user_id INTEGER NOT NULL REFERENCES users(id), status VARCHAR(40) DEFAULT 'INVITED' NOT NULL, invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, joined_at TIMESTAMP, left_at TIMESTAMP, is_muted BOOLEAN DEFAULT false NOT NULL, is_camera_enabled BOOLEAN DEFAULT true NOT NULL)",
        "CREATE INDEX IF NOT EXISTS ix_call_participants_call_session_id ON call_participants(call_session_id)",
        "CREATE INDEX IF NOT EXISTS ix_call_participants_user_id ON call_participants(user_id)",
    ]
    with engine.begin() as connection:
        if connection.dialect.name == "postgresql":
            for permission in [
                "ROOM_FORCE_JOIN",
                "ROOM_LOCK_OVERRIDE",
                "SECRET_VIBE_OVERRIDE",
                "MANAGE_STORE_CATALOG",
                "MANAGE_ASSETS",
                "MANAGE_ECONOMY_RULES",
                "MANAGE_VIP_RULES",
                "MANAGE_SVIP_RULES",
                "MANAGE_LEVEL_RULES",
                "MANAGE_ROLES",
                "MANAGE_PERMISSIONS",
                "GRANT_STEALTH",
                "USE_STEALTH",
                "MANAGE_ROOM_PRIVACY",
                "MANAGE_ROOM_ASSETS",
                "MANAGE_GIFTS",
                "MANAGE_GIFT_CATEGORIES",
            ]:
                connection.execute(text(f"ALTER TYPE specialpermissionname ADD VALUE IF NOT EXISTS '{permission}'"))
            connection.execute(text("ALTER TABLE cdn_media_assets ALTER COLUMN public_user_id TYPE BIGINT"))
        for statement in statements:
            connection.execute(text(statement))


_ensure_runtime_schema()

app = FastAPI(title="Vibe Match API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/")
def root():
    return {"message": "Vibe Match backend running", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy", "service": "vibe-match-backend"}


app.include_router(auth.router)
app.include_router(app_source_registry.router)
app.include_router(users.router)
app.include_router(role_badges.router)
app.include_router(admin.router)
app.include_router(media_safety_admin.router)
app.include_router(moderation.router)
app.include_router(super_owner.router)
app.include_router(control_center.router)
app.include_router(game_pool_admin.router)
app.include_router(game_props_admin.router)
app.include_router(rooms.router)
app.include_router(room_levels.router)
app.include_router(cricket.router)
app.include_router(families.router)
app.include_router(families_economy.router)
app.include_router(home_banners.router)
app.include_router(inbox.router)
app.include_router(inbox_backup_google.router)
app.include_router(love_bonds.router)
app.include_router(relationship_exp.router)
app.include_router(inbox_ws.router)
app.include_router(calls.router)
app.include_router(media_realtime_auth.router)
app.include_router(room_realtime.router)
app.include_router(room_realtime_commands.router)
app.include_router(experience.router)
app.include_router(experience_room_public.router)
app.include_router(social.router)
app.include_router(vibes.router)
app.include_router(notifications.router)
app.include_router(push.router)
app.include_router(presence.router)
app.include_router(profile_display.router)
app.include_router(media.router)
app.include_router(room_music_media.router)
app.include_router(mvp_core.router)
app.include_router(mvp_social.router)
app.include_router(mvp_economy.router)
app.include_router(mvp_operations.router)
app.include_router(mvp_room_modes.router)
app.include_router(internal_test.router)
app.include_router(economy.router)
app.include_router(economy_master.router)
app.include_router(economy_gift_public.router)
app.include_router(gift_catalog.router)
app.include_router(economy_admin.router)
app.include_router(games.router)
app.include_router(games_master.router)
app.include_router(game_settlements.router)
app.include_router(lucky_gifts.router)
app.include_router(lucky_coins.router)
app.include_router(store_router)
app.include_router(rankings.router)
app.include_router(coin_sales.router)
app.include_router(vip_admin.router)
app.include_router(wallet.router)