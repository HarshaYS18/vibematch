from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomySupplyAdminCutoverTests(unittest.TestCase):
    def test_core_supply_admin_delegates_to_economy(self):
        route=(ROOT/"backend/app/api/routes/economy_admin.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.mint_supply",route)
        self.assertIn("economy_service_client.allocate_supply",route)
        self.assertNotIn("economy_service.mint_to_pool(db=db",route)
        self.assertNotIn("economy_service.allocate_pool_to_pool(db=db",route)

    def test_supply_commands_are_idempotent_economy_transactions(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/supply/mint"',internal)
        self.assertIn('@router.post("/supply/allocate"',internal)
        self.assertIn('operation="supply.mint"',internal)
        self.assertIn('operation="supply.allocate"',internal)
        self.assertIn("economy.supply.minted.v1",internal)
        self.assertIn("economy.supply.allocated.v1",internal)

    def test_legacy_helpers_support_outer_transaction(self):
        service=(ROOT/"backend/app/services/economy_service.py").read_text(encoding="utf-8")
        self.assertIn("def mint_to_pool(",service)
        self.assertIn("*, commit: bool = True",service)
        self.assertIn("def allocate_pool_to_pool(",service)

if __name__=="__main__":
    unittest.main()
