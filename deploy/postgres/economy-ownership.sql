-- Complete Economy Service PostgreSQL ownership boundary.
-- Economy is the exclusive writer for financial truth. Core and other
-- deployables may receive the reader role only for bounded composite reads.
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_economy_owner') THEN CREATE ROLE funkey_economy_owner NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_economy_runtime') THEN CREATE ROLE funkey_economy_runtime NOLOGIN; END IF;
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='funkey_economy_reader') THEN CREATE ROLE funkey_economy_reader NOLOGIN; END IF;
END $$;

GRANT USAGE ON SCHEMA public TO funkey_economy_runtime;
GRANT USAGE ON SCHEMA public TO funkey_economy_reader;

ALTER TABLE user_wallets OWNER TO funkey_economy_owner;
ALTER TABLE wallet_ledger OWNER TO funkey_economy_owner;
ALTER TABLE coin_supply_pools OWNER TO funkey_economy_owner;
ALTER TABLE coin_pool_ledger OWNER TO funkey_economy_owner;
ALTER TABLE game_pools OWNER TO funkey_economy_owner;
ALTER TABLE game_pool_ledger OWNER TO funkey_economy_owner;
ALTER TABLE coin_sale_orders OWNER TO funkey_economy_owner;
ALTER TABLE gift_transactions OWNER TO funkey_economy_owner;
ALTER TABLE ruby_withdraw_requests OWNER TO funkey_economy_owner;
ALTER TABLE economy_transactions OWNER TO funkey_economy_owner;
ALTER TABLE economy_journal_entries OWNER TO funkey_economy_owner;
ALTER TABLE economy_house_reservations OWNER TO funkey_economy_owner;
ALTER TABLE economy_bulk_grants OWNER TO funkey_economy_owner;
ALTER TABLE economy_bulk_grant_recipients OWNER TO funkey_economy_owner;
ALTER TABLE gift_catalog_categories OWNER TO funkey_economy_owner;
ALTER TABLE gift_catalog_items OWNER TO funkey_economy_owner;
ALTER TABLE economy_rule_sets OWNER TO funkey_economy_owner;
ALTER TABLE economy_rule_levels OWNER TO funkey_economy_owner;
ALTER TABLE lucky_gift_transactions OWNER TO funkey_economy_owner;
ALTER TABLE user_lucky_gift_stats OWNER TO funkey_economy_owner;
ALTER TABLE lucky_packets OWNER TO funkey_economy_owner;
ALTER TABLE lucky_packet_claims OWNER TO funkey_economy_owner;

REVOKE ALL ON TABLE
  user_wallets,wallet_ledger,coin_supply_pools,coin_pool_ledger,
  game_pools,game_pool_ledger,coin_sale_orders,gift_transactions,
  ruby_withdraw_requests,economy_transactions,economy_journal_entries,economy_house_reservations,
  economy_bulk_grants,economy_bulk_grant_recipients,
  gift_catalog_categories,gift_catalog_items,economy_rule_sets,economy_rule_levels,
  lucky_gift_transactions,user_lucky_gift_stats,lucky_packets,lucky_packet_claims
FROM PUBLIC;

GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE
  user_wallets,wallet_ledger,coin_supply_pools,coin_pool_ledger,
  game_pools,game_pool_ledger,coin_sale_orders,gift_transactions,
  ruby_withdraw_requests,economy_transactions,economy_journal_entries,economy_house_reservations,
  economy_bulk_grants,economy_bulk_grant_recipients,
  gift_catalog_categories,gift_catalog_items,economy_rule_sets,economy_rule_levels,
  lucky_gift_transactions,user_lucky_gift_stats,lucky_packets,lucky_packet_claims
TO funkey_economy_runtime;

-- Economy may read identity/room context but does not own it.
GRANT SELECT ON TABLE
  users,user_roles,special_permissions,rooms,room_participants
TO funkey_economy_runtime;

-- VIP status is a derived Economy projection from recharge/value history.
-- This grant does not transfer ownership of user/profile authority.
GRANT SELECT,INSERT,UPDATE ON TABLE user_vip_statuses TO funkey_economy_runtime;

GRANT INSERT ON TABLE event_outbox TO funkey_economy_runtime;
GRANT SELECT,INSERT ON TABLE admin_logs TO funkey_economy_runtime;

-- Core/BFF compatibility reads may inspect Economy state but cannot mutate it.
GRANT SELECT ON TABLE
  user_wallets,wallet_ledger,coin_supply_pools,coin_pool_ledger,
  game_pools,game_pool_ledger,coin_sale_orders,gift_transactions,
  ruby_withdraw_requests,economy_transactions,economy_journal_entries,economy_house_reservations,
  gift_catalog_categories,gift_catalog_items,economy_rule_sets,economy_rule_levels,
  lucky_gift_transactions,user_lucky_gift_stats
TO funkey_economy_reader;

DO $$ DECLARE t text; s text; BEGIN
FOREACH t IN ARRAY ARRAY[
  'user_wallets','wallet_ledger','coin_supply_pools','coin_pool_ledger',
  'game_pools','game_pool_ledger','coin_sale_orders','gift_transactions',
  'ruby_withdraw_requests','economy_transactions','economy_journal_entries','economy_house_reservations',
  'economy_bulk_grants','economy_bulk_grant_recipients',
  'gift_catalog_categories','gift_catalog_items','economy_rule_sets','economy_rule_levels',
  'lucky_gift_transactions','user_lucky_gift_stats','lucky_packets','lucky_packet_claims'
] LOOP
  s:=pg_get_serial_sequence(t,'id');
  IF s IS NOT NULL THEN
    EXECUTE format('ALTER SEQUENCE %s OWNER TO funkey_economy_owner',s);
    EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_economy_runtime',s);
  END IF;
END LOOP;
s:=pg_get_serial_sequence('admin_logs','id');
IF s IS NOT NULL THEN EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO funkey_economy_runtime',s); END IF;
END $$;

-- Deployment binding:
--   GRANT funkey_economy_runtime TO <production_economy_login>;
--   GRANT funkey_economy_reader TO <production_core_api_login>;
-- Never grant funkey_economy_runtime to core-api, Game Platform, Inbox,
-- Profile/Social, workers, Realtime or Flutter-facing credentials.
