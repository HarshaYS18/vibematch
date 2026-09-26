-- Chunk 24: Vibes Service PostgreSQL ownership boundary.
-- Run with a provider/admin or migration role after Alembic reaches head.
-- Production LOGIN roles/credentials remain external secrets.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'funkey_vibes_owner') THEN
        CREATE ROLE funkey_vibes_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'funkey_vibes_runtime') THEN
        CREATE ROLE funkey_vibes_runtime NOLOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO funkey_vibes_runtime;

ALTER TABLE vibe_posts OWNER TO funkey_vibes_owner;
ALTER TABLE vibe_comments OWNER TO funkey_vibes_owner;
ALTER TABLE vibe_comment_reactions OWNER TO funkey_vibes_owner;
ALTER TABLE vibe_reactions OWNER TO funkey_vibes_owner;
ALTER TABLE vibe_shares OWNER TO funkey_vibes_owner;
ALTER TABLE vibe_saves OWNER TO funkey_vibes_owner;
ALTER TABLE vibe_reports OWNER TO funkey_vibes_owner;

REVOKE ALL ON TABLE
    vibe_posts,
    vibe_comments,
    vibe_comment_reactions,
    vibe_reactions,
    vibe_shares,
    vibe_saves,
    vibe_reports
FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    vibe_posts,
    vibe_comments,
    vibe_comment_reactions,
    vibe_reactions,
    vibe_shares,
    vibe_saves,
    vibe_reports
TO funkey_vibes_runtime;

GRANT SELECT ON TABLE users, user_roles, user_follows TO funkey_vibes_runtime;
GRANT INSERT ON TABLE event_outbox TO funkey_vibes_runtime;

DO $$
DECLARE
    table_name text;
    sequence_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'vibe_posts',
        'vibe_comments',
        'vibe_comment_reactions',
        'vibe_reactions',
        'vibe_shares',
        'vibe_saves',
        'vibe_reports'
    ]
    LOOP
        sequence_name := pg_get_serial_sequence(table_name, 'id');
        IF sequence_name IS NOT NULL THEN
            EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_vibes_owner', sequence_name);
            EXECUTE format(
                'GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_vibes_runtime',
                sequence_name
            );
        END IF;
    END LOOP;
END
$$;

-- Deployment binding:
--   GRANT funkey_vibes_runtime TO <production_vibes_login>;
-- Keep the core API login out of funkey_vibes_runtime after cutover.
