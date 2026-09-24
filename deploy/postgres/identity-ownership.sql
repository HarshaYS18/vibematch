-- Chunk 27 Identity ownership boundary.
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_identity_owner') THEN CREATE ROLE funkey_identity_owner NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_identity_runtime') THEN CREATE ROLE funkey_identity_runtime NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO funkey_identity_runtime;
ALTER TABLE users OWNER TO funkey_identity_owner;
ALTER TABLE auth_identities OWNER TO funkey_identity_owner;
ALTER TABLE login_history OWNER TO funkey_identity_owner;
ALTER TABLE identity_devices OWNER TO funkey_identity_owner;
ALTER TABLE identity_sessions OWNER TO funkey_identity_owner;
REVOKE ALL ON TABLE users,auth_identities,login_history,identity_devices,identity_sessions FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE users,auth_identities,login_history,identity_devices,identity_sessions TO funkey_identity_runtime;
GRANT SELECT,INSERT ON TABLE user_roles TO funkey_identity_runtime;
GRANT SELECT ON TABLE user_bans,device_bans TO funkey_identity_runtime;
DO $$ DECLARE t text; s text; BEGIN
FOREACH t IN ARRAY ARRAY['users','auth_identities','login_history','identity_devices','identity_sessions'] LOOP
s:=pg_get_serial_sequence(t,'id'); IF s IS NOT NULL THEN EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_identity_owner',s); EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_identity_runtime',s); END IF;
END LOOP; END $$;
