-- Chunk 28 Game Platform ownership boundary.
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_game_platform_owner') THEN CREATE ROLE funkey_game_platform_owner NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_game_platform_runtime') THEN CREATE ROLE funkey_game_platform_runtime NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_game_platform_reader') THEN CREATE ROLE funkey_game_platform_reader NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO funkey_game_platform_runtime;
GRANT USAGE ON SCHEMA public TO funkey_game_platform_reader;
ALTER TABLE game_definitions OWNER TO funkey_game_platform_owner;
ALTER TABLE game_rounds OWNER TO funkey_game_platform_owner;
ALTER TABLE game_round_players OWNER TO funkey_game_platform_owner;
ALTER TABLE game_bets OWNER TO funkey_game_platform_owner;
ALTER TABLE game_risk_audits OWNER TO funkey_game_platform_owner;
ALTER TABLE user_game_stats OWNER TO funkey_game_platform_owner;
REVOKE ALL ON TABLE game_definitions,game_rounds,game_round_players,game_bets,game_risk_audits,user_game_stats FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE game_definitions,game_rounds,game_round_players,game_bets,game_risk_audits,user_game_stats TO funkey_game_platform_runtime;
GRANT SELECT ON TABLE users,user_roles,rooms TO funkey_game_platform_runtime;
GRANT INSERT ON TABLE event_outbox TO funkey_game_platform_runtime;
GRANT SELECT ON TABLE game_definitions,game_rounds,game_round_players,game_bets,game_risk_audits,user_game_stats TO funkey_game_platform_reader;
DO $$ DECLARE t text; s text; BEGIN
FOREACH t IN ARRAY ARRAY['game_definitions','game_rounds','game_round_players','game_bets','game_risk_audits','user_game_stats'] LOOP
s:=pg_get_serial_sequence(t,'id'); IF s IS NOT NULL THEN EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_game_platform_owner',s); EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_game_platform_runtime',s); END IF;
END LOOP; END $$;
