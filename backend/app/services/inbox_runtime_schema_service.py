from sqlalchemy import text
from sqlalchemy.engine import Engine


INBOX_RUNTIME_SCHEMA_STATEMENTS = [
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


INBOX_RUNTIME_SCHEMA_INDEXES = [
    "CREATE INDEX IF NOT EXISTS ix_inbox_user_preferences_user_id ON inbox_user_preferences (user_id)",
    "CREATE INDEX IF NOT EXISTS ix_inbox_conversation_user_settings_conversation_user ON inbox_conversation_user_settings (conversation_id, user_id)",
    "CREATE INDEX IF NOT EXISTS ix_inbox_message_user_states_message_user ON inbox_message_user_states (message_id, user_id)",
    "CREATE INDEX IF NOT EXISTS ix_inbox_stories_owner_active ON inbox_stories (owner_user_id, is_active)",
    "CREATE INDEX IF NOT EXISTS ix_call_sessions_conversation_status ON call_sessions (conversation_id, status)",
    "CREATE INDEX IF NOT EXISTS ix_call_participants_call_user ON call_participants (call_session_id, user_id)",
]


def ensure_inbox_runtime_schema(engine: Engine) -> None:
    """Dev/beta migration guard for Inbox features.

    Base.metadata.create_all creates missing tables, but existing local beta
    databases need additive columns/indexes as Inbox features evolve before a
    formal Alembic migration pipeline is introduced.
    """
    with engine.begin() as connection:
        if connection.dialect.name != "postgresql":
            return
        for statement in INBOX_RUNTIME_SCHEMA_STATEMENTS:
            connection.execute(text(statement))
        for statement in INBOX_RUNTIME_SCHEMA_INDEXES:
            connection.execute(text(statement))
