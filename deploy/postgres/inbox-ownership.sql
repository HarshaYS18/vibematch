-- Chunk 23: Inbox Service PostgreSQL ownership boundary.
-- Run with a provider/admin or migration role after Alembic reaches head.
-- This script creates NOLOGIN group roles only; production LOGIN roles and
-- credentials are provisioned by the external secret/identity platform.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'funkey_inbox_owner') THEN
        CREATE ROLE funkey_inbox_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'funkey_inbox_runtime') THEN
        CREATE ROLE funkey_inbox_runtime NOLOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO funkey_inbox_runtime;

-- Chat/call durable authority. Stories deliberately remain outside this list
-- until the later Vibes/Profile ownership chunk.
ALTER TABLE inbox_conversations OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_participants OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_messages OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_read_receipts OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_reports OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_lock_settings OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_lock_otps OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_user_preferences OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_conversation_user_settings OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_message_user_states OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_backup_settings OWNER TO funkey_inbox_owner;
ALTER TABLE inbox_backup_jobs OWNER TO funkey_inbox_owner;
ALTER TABLE call_sessions OWNER TO funkey_inbox_owner;
ALTER TABLE call_participants OWNER TO funkey_inbox_owner;

REVOKE ALL ON TABLE
    inbox_conversations,
    inbox_participants,
    inbox_messages,
    inbox_read_receipts,
    inbox_reports,
    inbox_lock_settings,
    inbox_lock_otps,
    inbox_user_preferences,
    inbox_conversation_user_settings,
    inbox_message_user_states,
    inbox_backup_settings,
    inbox_backup_jobs,
    call_sessions,
    call_participants
FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    inbox_conversations,
    inbox_participants,
    inbox_messages,
    inbox_read_receipts,
    inbox_reports,
    inbox_lock_settings,
    inbox_lock_otps,
    inbox_user_preferences,
    inbox_conversation_user_settings,
    inbox_message_user_states,
    inbox_backup_settings,
    inbox_backup_jobs,
    call_sessions,
    call_participants
TO funkey_inbox_runtime;

-- Identity/profile remain separate authorities. Inbox only needs bounded reads
-- to authenticate JWT subjects and resolve display/staff context.
GRANT SELECT ON TABLE users, user_roles TO funkey_inbox_runtime;

-- Transfer serial/identity sequences with their Inbox tables and grant only
-- sequence consumption to the runtime group.
DO $$
DECLARE
    table_name text;
    sequence_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'inbox_conversations',
        'inbox_participants',
        'inbox_messages',
        'inbox_read_receipts',
        'inbox_reports',
        'inbox_lock_settings',
        'inbox_lock_otps',
        'inbox_user_preferences',
        'inbox_conversation_user_settings',
        'inbox_message_user_states',
        'inbox_backup_settings',
        'inbox_backup_jobs',
        'call_sessions',
        'call_participants'
    ]
    LOOP
        sequence_name := pg_get_serial_sequence(table_name, 'id');
        IF sequence_name IS NOT NULL THEN
            EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_inbox_owner', sequence_name);
            EXECUTE format(
                'GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_inbox_runtime',
                sequence_name
            );
        END IF;
    END LOOP;
END
$$;

-- Deployment binding:
--   GRANT funkey_inbox_runtime TO <production_inbox_login>;
-- The migration/admin role must retain the ability to SET ROLE
-- funkey_inbox_owner for future Alembic changes. Do not grant the runtime group
-- to the core API login.
