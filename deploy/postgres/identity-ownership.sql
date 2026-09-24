-- Chunk 27 Identity ownership boundary.
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_identity_owner') THEN CREATE ROLE funkey_identity_owner NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_identity_runtime') THEN CREATE ROLE funkey_identity_runtime NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_identity_reader') THEN CREATE ROLE funkey_identity_reader NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO funkey_identity_runtime;
GRANT USAGE ON SCHEMA public TO funkey_identity_reader;
ALTER TABLE users OWNER TO funkey_identity_owner;
ALTER TABLE auth_identities OWNER TO funkey_identity_owner;
ALTER TABLE login_history OWNER TO funkey_identity_owner;
ALTER TABLE identity_devices OWNER TO funkey_identity_owner;
ALTER TABLE identity_sessions OWNER TO funkey_identity_owner;
ALTER TABLE user_roles OWNER TO funkey_identity_owner;
ALTER TABLE special_permissions OWNER TO funkey_identity_owner;
ALTER TABLE user_bans OWNER TO funkey_identity_owner;
ALTER TABLE device_bans OWNER TO funkey_identity_owner;
REVOKE ALL ON TABLE users,auth_identities,login_history,identity_devices,identity_sessions,user_roles,special_permissions,user_bans,device_bans FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE users,auth_identities,login_history,identity_devices,identity_sessions,user_roles,special_permissions,user_bans,device_bans TO funkey_identity_runtime;
GRANT SELECT,INSERT ON TABLE admin_logs TO funkey_identity_runtime;
GRANT SELECT ON TABLE users,user_roles,special_permissions,user_bans,device_bans TO funkey_identity_reader;
DO $$ DECLARE t text; s text; BEGIN
FOREACH t IN ARRAY ARRAY['users','auth_identities','login_history','identity_devices','identity_sessions','user_roles','special_permissions','user_bans','device_bans'] LOOP
s:=pg_get_serial_sequence(t,'id'); IF s IS NOT NULL THEN EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_identity_owner',s); EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_identity_runtime',s); END IF;
END LOOP; END $$;

-- Deployment binding:
--   GRANT funkey_identity_runtime TO <production_identity_login>;
--   GRANT funkey_identity_reader TO <production_core_api_login>;
-- Core/composite readers receive no auth/session/account mutation privileges.
