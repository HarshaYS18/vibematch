from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomyLegacyGamePoolCutoverTests(unittest.TestCase):
    def test_legacy_game_pool_command_delegates_and_is_authorized(self):
        route=(ROOT/"backend/app/api/routes/economy_admin.py").read_text(encoding="utf-8")
        start=route.index('@router.post("/gaming/pools")')
        end=route.index('\n\n@router.post("/gaming/rounds")',start)
        block=route[start:end]
        self.assertIn("require_super_owner(current_user)",block)
        self.assertIn("economy_service_client.configure_game_pool",block)
        self.assertNotIn("economy_service.create_game_pool",block)

    def test_game_pool_financial_config_is_economy_command(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/game-pools/configure"',internal)
        self.assertIn('operation="game_pool.configure"',internal)
        self.assertIn("economy.game_pool.configured.v1",internal)

    def test_legacy_round_lifecycle_facade_delegates_to_game_platform(self):
        route=(ROOT/"backend/app/api/routes/economy_admin.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/gaming/rounds")',route)
        self.assertIn("require_super_owner(current_user)",route)
        self.assertIn("game_platform_service_client.create_round",route)
        self.assertNotIn("economy_service.create_game_round",route)

if __name__=="__main__":
    unittest.main()
