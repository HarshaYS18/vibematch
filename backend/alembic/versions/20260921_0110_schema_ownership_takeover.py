"""transfer runtime schema ownership to Alembic

This is a one-time compatibility bridge for databases that were historically
created by SQLAlchemy create_all() and then patched at application startup.
All schema mutation now runs through Alembic. New schema changes must be added
as normal, explicit Alembic revisions.

Revision ID: 20260921_0110
Revises: 20260921_0100
Create Date: 2026-09-21
"""

from alembic import op

from app import models  # noqa: F401 - registers every ORM table on Base.metadata
from app.database import Base


revision = "20260921_0110"
down_revision = "20260921_0100"
branch_labels = None
depends_on = None


RUNTIME_SCHEMA_STATEMENTS = [
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

INBOX_SCHEMA_STATEMENTS = [
    # Inbox per-user privacy/preferences.
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS strangers_can_message BOOLEAN DEFAULT true NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS strangers_can_mention_in_vibes BOOLEAN DEFAULT true NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS read_receipts_enabled BOOLEAN DEFAULT true NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS online_visibility VARCHAR(32) DEFAULT 'everyone' NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS last_seen_visibility VARCHAR(32) DEFAULT 'everyone' NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS typing_activity_visibility VARCHAR(32) DEFAULT 'everyone' NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS story_visibility VARCHAR(32) DEFAULT 'friends' NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS device_unlock_enabled BOOLEAN DEFAULT false NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS default_chat_theme VARCHAR(64) DEFAULT 'pearl' NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS default_wallpaper_key VARCHAR(80) DEFAULT 'premium_pearl' NOT NULL",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS default_wallpaper_url VARCHAR(700)",
    "ALTER TABLE inbox_user_preferences ADD COLUMN IF NOT EXISTS metadata_json JSON",
    "UPDATE inbox_user_preferences SET online_visibility = 'everyone' WHERE online_visibility IS NULL OR online_visibility = ''",
    "UPDATE inbox_user_preferences SET last_seen_visibility = 'everyone' WHERE last_seen_visibility IS NULL OR last_seen_visibility = ''",
    "UPDATE inbox_user_preferences SET typing_activity_visibility = 'everyone' WHERE typing_activity_visibility IS NULL OR typing_activity_visibility = ''",
    "UPDATE inbox_user_preferences SET story_visibility = 'friends' WHERE story_visibility IS NULL OR story_visibility = ''",
    "UPDATE inbox_user_preferences SET default_chat_theme = 'pearl' WHERE default_chat_theme IS NULL OR default_chat_theme = ''",
    "UPDATE inbox_user_preferences SET default_wallpaper_key = 'premium_pearl' WHERE default_wallpaper_key IS NULL OR default_wallpaper_key = ''",

    # Per-conversation theme / wallpaper source of truth.
    "ALTER TABLE inbox_conversation_user_settings ADD COLUMN IF NOT EXISTS chat_theme VARCHAR(64)",
    "ALTER TABLE inbox_conversation_user_settings ADD COLUMN IF NOT EXISTS wallpaper_key VARCHAR(80)",
    "ALTER TABLE inbox_conversation_user_settings ADD COLUMN IF NOT EXISTS wallpaper_url VARCHAR(700)",
    "ALTER TABLE inbox_conversation_user_settings ADD COLUMN IF NOT EXISTS metadata_json JSON",

    # Per-user message state for Remove-for-me without altering global message history.
    "ALTER TABLE inbox_message_user_states ADD COLUMN IF NOT EXISTS is_deleted_for_user BOOLEAN DEFAULT false NOT NULL",
    "UPDATE inbox_message_user_states SET is_deleted_for_user = false WHERE is_deleted_for_user IS NULL",

    # Story rail tables/columns.
    "ALTER TABLE inbox_stories ADD COLUMN IF NOT EXISTS media_type VARCHAR(32) DEFAULT 'image' NOT NULL",
    "ALTER TABLE inbox_stories ADD COLUMN IF NOT EXISTS caption TEXT",
    "ALTER TABLE inbox_stories ADD COLUMN IF NOT EXISTS visibility VARCHAR(32) DEFAULT 'friends' NOT NULL",
    "ALTER TABLE inbox_stories ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true NOT NULL",
    "ALTER TABLE inbox_stories ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0 NOT NULL",
    "ALTER TABLE inbox_stories ADD COLUMN IF NOT EXISTS metadata_json JSON",
    "UPDATE inbox_stories SET media_type = 'image' WHERE media_type IS NULL OR media_type = ''",
    "UPDATE inbox_stories SET visibility = 'friends' WHERE visibility IS NULL OR visibility = ''",
    "UPDATE inbox_stories SET is_active = true WHERE is_active IS NULL",
    "UPDATE inbox_stories SET view_count = 0 WHERE view_count IS NULL",

    # Direct Inbox call state.
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS conversation_id INTEGER",
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS room_public_id VARCHAR(32)",
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS answered_at TIMESTAMP",
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS ended_at TIMESTAMP",
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS duration_seconds INTEGER",
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS end_reason VARCHAR(120)",
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS is_video_enabled BOOLEAN DEFAULT false NOT NULL",
    "ALTER TABLE call_sessions ADD COLUMN IF NOT EXISTS is_group_call BOOLEAN DEFAULT false NOT NULL",
    "UPDATE call_sessions SET is_video_enabled = false WHERE is_video_enabled IS NULL",
    "UPDATE call_sessions SET is_group_call = false WHERE is_group_call IS NULL",
    "ALTER TABLE call_participants ADD COLUMN IF NOT EXISTS joined_at TIMESTAMP",
    "ALTER TABLE call_participants ADD COLUMN IF NOT EXISTS left_at TIMESTAMP",
    "ALTER TABLE call_participants ADD COLUMN IF NOT EXISTS is_muted BOOLEAN DEFAULT false NOT NULL",
    "ALTER TABLE call_participants ADD COLUMN IF NOT EXISTS is_camera_enabled BOOLEAN DEFAULT true NOT NULL",
    "UPDATE call_participants SET is_muted = false WHERE is_muted IS NULL",
    "UPDATE call_participants SET is_camera_enabled = true WHERE is_camera_enabled IS NULL",
]

INBOX_SCHEMA_INDEXES = [
    "CREATE INDEX IF NOT EXISTS ix_inbox_user_preferences_user_id ON inbox_user_preferences (user_id)",
    "CREATE INDEX IF NOT EXISTS ix_inbox_conversation_user_settings_conversation_user ON inbox_conversation_user_settings (conversation_id, user_id)",
    "CREATE INDEX IF NOT EXISTS ix_inbox_message_user_states_message_user ON inbox_message_user_states (message_id, user_id)",
    "CREATE INDEX IF NOT EXISTS ix_inbox_stories_owner_active ON inbox_stories (owner_user_id, is_active)",
    "CREATE INDEX IF NOT EXISTS ix_call_sessions_conversation_status ON call_sessions (conversation_id, status)",
    "CREATE INDEX IF NOT EXISTS ix_call_participants_call_user ON call_participants (call_session_id, user_id)",
]


SPECIAL_PERMISSION_VALUES = [
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
]


def upgrade() -> None:
    bind = op.get_bind()

    # Historical databases relied on create_all() for the original table set.
    # Running it here (and only here) transfers that bootstrap responsibility
    # into Alembic while preserving existing installations via checkfirst.
    Base.metadata.create_all(bind=bind, checkfirst=True)

    if bind.dialect.name == "postgresql":
        for permission in SPECIAL_PERMISSION_VALUES:
            op.execute(
                "ALTER TYPE specialpermissionname "
                f"ADD VALUE IF NOT EXISTS '{permission}'"
            )
        op.execute(
            "ALTER TABLE cdn_media_assets "
            "ALTER COLUMN public_user_id TYPE BIGINT"
        )

    for statement in RUNTIME_SCHEMA_STATEMENTS:
        # Enum and cdn_media_assets mutations above are handled explicitly to
        # avoid executing them twice.
        if statement.startswith("ALTER TYPE specialpermissionname"):
            continue
        if statement.startswith("ALTER TABLE cdn_media_assets ALTER COLUMN public_user_id"):
            continue
        op.execute(statement)

    for statement in INBOX_SCHEMA_STATEMENTS:
        op.execute(statement)
    for statement in INBOX_SCHEMA_INDEXES:
        op.execute(statement)


def downgrade() -> None:
    raise RuntimeError(
        "20260921_0110 is an irreversible schema-ownership bridge; "
        "restore from a database backup instead of dropping live data."
    )
