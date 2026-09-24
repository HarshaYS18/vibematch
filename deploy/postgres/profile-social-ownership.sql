-- Chunk 27 Profile/Social ownership boundary.
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_profile_social_owner') THEN CREATE ROLE funkey_profile_social_owner NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_profile_social_runtime') THEN CREATE ROLE funkey_profile_social_runtime NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO funkey_profile_social_runtime;
ALTER TABLE user_follows OWNER TO funkey_profile_social_owner;
ALTER TABLE user_blocks OWNER TO funkey_profile_social_owner;
ALTER TABLE love_bonds OWNER TO funkey_profile_social_owner;
ALTER TABLE love_bond_requests OWNER TO funkey_profile_social_owner;
ALTER TABLE profile_visits OWNER TO funkey_profile_social_owner;
ALTER TABLE user_stealth_states OWNER TO funkey_profile_social_owner;
ALTER TABLE profile_display_audits OWNER TO funkey_profile_social_owner;
ALTER TABLE family_economy_stats OWNER TO funkey_profile_social_owner;
ALTER TABLE family_member_stats OWNER TO funkey_profile_social_owner;
REVOKE ALL ON TABLE user_follows,user_blocks,love_bonds,love_bond_requests,profile_visits,user_stealth_states,profile_display_audits,family_economy_stats,family_member_stats FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE user_follows,user_blocks,love_bonds,love_bond_requests,profile_visits,user_stealth_states,profile_display_audits,family_economy_stats,family_member_stats TO funkey_profile_social_runtime;
GRANT SELECT ON TABLE users TO funkey_profile_social_runtime;
GRANT UPDATE (display_name,avatar_url,bio,cover_photo_urls,date_of_birth,gender,profession,marital_status,friend_gender_preference,friend_marital_preference,interests,updated_at) ON TABLE users TO funkey_profile_social_runtime;
GRANT SELECT,INSERT,UPDATE ON TABLE love_bond_inventory TO funkey_profile_social_runtime;
GRANT SELECT ON TABLE cdn_media_assets,user_roles,special_permissions,user_vip_statuses,user_experience_statuses,user_store_inventory,store_items TO funkey_profile_social_runtime;
GRANT INSERT ON TABLE event_outbox TO funkey_profile_social_runtime;
DO $$ DECLARE t text; s text; BEGIN
FOREACH t IN ARRAY ARRAY['user_follows','user_blocks','love_bonds','love_bond_requests','profile_visits','user_stealth_states','profile_display_audits','family_economy_stats','family_member_stats'] LOOP
s:=pg_get_serial_sequence(t,'id'); IF s IS NOT NULL THEN EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_profile_social_owner',s); EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_profile_social_runtime',s); END IF;
END LOOP;
s:=pg_get_serial_sequence('love_bond_inventory','id'); IF s IS NOT NULL THEN EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_profile_social_runtime',s); END IF;
END $$;
