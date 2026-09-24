from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class GamePlatformServiceFoundationTests(unittest.TestCase):
    def test_deployable_and_proxy_seam_exist(self):
        for relative in ("apps/game-platform-service/main.py","apps/game-platform-service/database.py","apps/game-platform-service/Dockerfile","backend/app/api/routes/game_platform_proxy.py","deploy/kubernetes/base/game-platform.yaml","deploy/postgres/game-platform-ownership.sql"):
            self.assertTrue((ROOT/relative).exists(),relative)
    def test_service_mounts_canonical_game_routes_but_not_legacy_settlement_router(self):
        main=(ROOT/"apps/game-platform-service/main.py").read_text(encoding="utf-8")
        for token in ("games.router","games_master.router","games.admin_router"): self.assertIn(token,main)
        self.assertNotIn("game_settlements",main)
    def test_service_has_isolated_database_configuration(self):
        config=(ROOT/"backend/app/core/config.py").read_text(encoding="utf-8"); db=(ROOT/"apps/game-platform-service/database.py").read_text(encoding="utf-8")
        self.assertIn("GAME_PLATFORM_DATABASE_URL",config); self.assertIn("validate_game_platform_service",config); self.assertIn("GAME_PLATFORM_DATABASE_URL",db)
    def test_db_role_excludes_financial_tables(self):
        sql=(ROOT/"deploy/postgres/game-platform-ownership.sql").read_text(encoding="utf-8")
        for token in ("game_definitions","game_rounds","game_bets","user_game_stats"): self.assertIn(token,sql)
        for forbidden in ("user_wallets","wallet_ledger","game_pools","game_pool_ledger"): self.assertNotIn(forbidden,sql)
    def test_ci_builds_game_platform_image(self):
        workflow=(ROOT/".github/workflows/production-platform.yml").read_text(encoding="utf-8")
        self.assertIn("apps/game-platform-service/Dockerfile",workflow); self.assertIn("funkey-game-platform:ci",workflow)
if __name__=="__main__": unittest.main()
