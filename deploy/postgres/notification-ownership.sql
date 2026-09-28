-- Chunk 29 Notification Service PostgreSQL ownership boundary.
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_notification_owner') THEN CREATE ROLE funkey_notification_owner NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_notification_runtime') THEN CREATE ROLE funkey_notification_runtime NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO funkey_notification_runtime;
ALTER TABLE user_notifications OWNER TO funkey_notification_owner;
ALTER TABLE push_device_tokens OWNER TO funkey_notification_owner;
ALTER TABLE notification_preferences OWNER TO funkey_notification_owner;
ALTER TABLE notification_templates OWNER TO funkey_notification_owner;
ALTER TABLE notification_deliveries OWNER TO funkey_notification_owner;
REVOKE ALL ON TABLE user_notifications,push_device_tokens,notification_preferences,notification_templates,notification_deliveries FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE user_notifications,push_device_tokens,notification_preferences,notification_templates,notification_deliveries TO funkey_notification_runtime;
GRANT SELECT ON TABLE users,user_roles TO funkey_notification_runtime;
GRANT INSERT ON TABLE event_outbox TO funkey_notification_runtime;
DO $$ DECLARE t text; s text; BEGIN
FOREACH t IN ARRAY ARRAY['user_notifications','push_device_tokens','notification_preferences','notification_templates','notification_deliveries'] LOOP
s:=pg_get_serial_sequence(t,'id'); IF s IS NOT NULL THEN EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_notification_owner',s); EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_notification_runtime',s); END IF;
END LOOP; END $$;
-- Deployment binding: GRANT funkey_notification_runtime TO <production_notification_login>;
-- Do not grant funkey_notification_runtime to core-api or generic worker logins.
