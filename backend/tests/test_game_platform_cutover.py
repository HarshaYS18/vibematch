from pathlib import Path
import json
import unittest

ROOT=Path(__file__).resolve().parents[2]


class GamePlatformCutoverTests(unittest.TestCase):
    def test_core_routes_game_authority_through_proxy_without_shadowing_finance(self):
        router=(ROOT/"backend/app/api/router.py").read_text(encoding="utf-8")
        self.assertIn("game_platform_proxy.router",router)
        self.assertIn("game_platform_proxy.admin_router",router)
        for forbidden in ("games.router","games_master.router","games.admin_router"):
            self.assertNotIn(forbidden,router)
        self.assertLess(router.index("game_settlements.router"),router.index("game_platform_proxy.router"))
        self.assertLess(router.index("game_props_admin.router"),router.index("game_platform_proxy.admin_router"))

    def test_legacy_game_money_facade_is_economy_only(self):
        source=(ROOT/"backend/app/api/routes/game_settlements.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.game_wager",source)
        self.assertIn("economy_service_client.game_settle",source)
        self.assertIn('Idempotency-Key',source)
        self.assertNotIn("game_settlement_service",source)
        for forbidden in ("UserWallet","WalletLedger","house_pool_service"):
            self.assertNotIn(forbidden,source)

    def test_authority_registry_marks_chunk_28_live(self):
        payload=json.loads((ROOT/"contracts/architecture/authorities.yaml").read_text(encoding="utf-8"))
        states={item["id"]:item for item in payload["states"]}
        self.assertEqual("game-platform-service",states["games.catalog_rounds"]["current_deployable"])
        self.assertIn("postgres:user_game_stats",states["games.catalog_rounds"]["current_storage"])
        self.assertEqual("economy-service",states["games.financial_settlement"]["current_deployable"])
        self.assertEqual("economy",states["games.financial_settlement"]["logical_owner"])

    def test_game_platform_db_role_excludes_financial_authority(self):
        sql=(ROOT/"deploy/postgres/game-platform-ownership.sql").read_text(encoding="utf-8")
        for table in ("game_definitions","game_sessions","game_rounds","game_bets","game_risk_audits","user_game_stats"):
            self.assertIn(f"ALTER TABLE {table} OWNER TO funkey_game_platform_owner",sql)
        for forbidden in ("ALTER TABLE user_wallets","ALTER TABLE wallet_ledger","ALTER TABLE game_pools","ALTER TABLE game_pool_ledger"):
            self.assertNotIn(forbidden,sql)

    def test_game_config_and_legacy_round_writers_are_service_owned(self):
        core_props=(ROOT/"backend/app/api/routes/game_props_admin.py").read_text(encoding="utf-8")
        game_admin=(ROOT/"apps/game-platform-service/admin_props.py").read_text(encoding="utf-8")
        economy_admin=(ROOT/"backend/app/api/routes/economy_admin.py").read_text(encoding="utf-8")
        self.assertNotIn("jungle_hunt_props_runtime_service",core_props)
        self.assertIn("jungle_hunt_props_runtime_service.update_props",game_admin)
        self.assertIn("game_platform_service_client.create_round",economy_admin)
        self.assertNotIn("economy_service.create_game_round",economy_admin)

    def test_game_platform_runtime_can_write_admin_audit_only(self):
        sql=(ROOT/"deploy/postgres/game-platform-ownership.sql").read_text(encoding="utf-8")
        self.assertIn("GRANT SELECT,INSERT ON TABLE admin_logs TO funkey_game_platform_runtime",sql)

    def test_game_master_reads_do_not_use_legacy_game_pool_side_effects(self):
        source=(ROOT/"backend/app/api/routes/games_master.py").read_text(encoding="utf-8")
        self.assertIn("game_platform_runtime_service as game_service",source)
        self.assertNotIn("global_jungle_game_service_v2",source)


if __name__=="__main__":
    unittest.main()
