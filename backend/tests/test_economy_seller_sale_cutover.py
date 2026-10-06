from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomySellerSaleCutoverTests(unittest.TestCase):
    def test_core_seller_sale_delegates(self):
        route=(ROOT/"backend/app/api/routes/economy_admin.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.seller_sale",route)
        self.assertNotIn("economy_service.sell_pool_coins_to_user(db=db",route)

    def test_seller_sale_is_atomic_idempotent_command(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/supply/seller-sale"',internal)
        self.assertIn('operation="supply.seller_sale"',internal)
        self.assertIn("economy.seller_sale.completed.v1",internal)
        service=(ROOT/"backend/app/services/economy_service.py").read_text(encoding="utf-8")
        self.assertIn("def sell_pool_coins_to_user(",service)
        self.assertIn("*, commit: bool = True",service)

if __name__=="__main__":
    unittest.main()
