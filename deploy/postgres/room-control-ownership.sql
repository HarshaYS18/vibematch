-- Chunk 26: Room Control Service PostgreSQL ownership boundary.
-- Run with a provider/admin or migration role after Alembic reaches head.
-- Production LOGIN roles/credentials remain external secrets.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'funkey_room_control_owner') THEN
        CREATE ROLE funkey_room_control_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'funkey_room_control_runtime') THEN
        CREATE ROLE funkey_room_control_runtime NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'funkey_room_control_reader') THEN
        CREATE ROLE funkey_room_control_reader NOLOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO funkey_room_control_runtime;
GRANT USAGE ON SCHEMA public TO funkey_room_control_reader;

ALTER TABLE rooms OWNER TO funkey_room_control_owner;
ALTER TABLE room_participants OWNER TO funkey_room_control_owner;
ALTER TABLE room_seat_states OWNER TO funkey_room_control_owner;
ALTER TABLE room_realtime_events OWNER TO funkey_room_control_owner;
ALTER TABLE room_member_requests OWNER TO funkey_room_control_owner;
ALTER TABLE room_seat_applications OWNER TO funkey_room_control_owner;
ALTER TABLE room_chat_messages OWNER TO funkey_room_control_owner;
ALTER TABLE room_kickouts OWNER TO funkey_room_control_owner;
ALTER TABLE room_themes OWNER TO funkey_room_control_owner;
ALTER TABLE user_room_theme_inventory OWNER TO funkey_room_control_owner;
ALTER TABLE room_theme_reviews OWNER TO funkey_room_control_owner;
ALTER TABLE cricket_tournaments OWNER TO funkey_room_control_owner;
ALTER TABLE cricket_matches OWNER TO funkey_room_control_owner;
ALTER TABLE cricket_ball_events OWNER TO funkey_room_control_owner;

REVOKE ALL ON TABLE
    rooms,
    room_participants,
    room_seat_states,
    room_realtime_events,
    room_member_requests,
    room_seat_applications,
    room_chat_messages,
    room_kickouts,
    room_themes,
    user_room_theme_inventory,
    room_theme_reviews,
    cricket_tournaments,
    cricket_matches,
    cricket_ball_events
FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    rooms,
    room_participants,
    room_seat_states,
    room_realtime_events,
    room_member_requests,
    room_seat_applications,
    room_chat_messages,
    room_kickouts,
    room_themes,
    user_room_theme_inventory,
    room_theme_reviews,
    cricket_tournaments,
    cricket_matches,
    cricket_ball_events
TO funkey_room_control_runtime;

-- Core/API compatibility facades may render room state but cannot mutate it.
GRANT SELECT ON TABLE
    rooms,
    room_participants,
    room_seat_states,
    room_realtime_events,
    room_member_requests,
    room_seat_applications,
    room_chat_messages,
    room_kickouts,
    room_themes,
    user_room_theme_inventory,
    room_theme_reviews,
    cricket_tournaments,
    cricket_matches,
    cricket_ball_events
TO funkey_room_control_reader;

-- Legacy DB presence is deliberately non-authoritative after the repair wave.
-- No production runtime role receives write access; Go/Redis socket leases are
-- the only connected-liveness writer.
REVOKE ALL ON TABLE user_room_presence FROM PUBLIC;
REVOKE ALL ON TABLE user_room_presence FROM funkey_room_control_runtime;
REVOKE ALL ON TABLE user_room_presence FROM funkey_room_control_reader;

-- Temporary bounded reads until Chunk 27 extracts identity/profile/social.
-- No write grants are intentionally provided for these authorities.
GRANT SELECT ON TABLE
    users,
    user_roles,
    special_permissions,
    user_follows,
    user_vip_statuses,
    user_experience_statuses,
    room_experience_statuses,
    user_wallets,
    wallet_ledger,
    gift_transactions,
    economy_rule_sets,
    economy_rule_levels,
    user_store_inventory,
    store_items
TO funkey_room_control_runtime;

-- Room state mutations publish durable domain events transactionally.
GRANT INSERT ON TABLE event_outbox TO funkey_room_control_runtime;

DO $$
DECLARE
    table_name text;
    sequence_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'rooms',
        'room_participants',
        'room_seat_states',
        'room_realtime_events',
        'room_member_requests',
        'room_seat_applications',
        'room_chat_messages',
        'room_kickouts',
        'room_themes',
        'user_room_theme_inventory',
        'room_theme_reviews',
        'cricket_tournaments',
        'cricket_matches',
        'cricket_ball_events'
    ]
    LOOP
        sequence_name := pg_get_serial_sequence(table_name, 'id');
        IF sequence_name IS NOT NULL THEN
            EXECUTE format(
                'ALTER SEQUENCE %s OWNER TO funkey_room_control_owner',
                sequence_name
            );
            EXECUTE format(
                'GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_room_control_runtime',
                sequence_name
            );
        END IF;
    END LOOP;

END
$$;

-- Deployment binding:
--   GRANT funkey_room_control_runtime TO <production_room_control_login>;
--   GRANT funkey_room_control_reader TO <production_core_api_login>;
-- Keep the core API login out of funkey_room_control_runtime after cutover.
