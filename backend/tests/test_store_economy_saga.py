from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class StoreEconomySagaTests(unittest.TestCase):
    def test_store_no_longer_writes_wallet_directly(self):
        source = (ROOT / "backend/app/services/store_service.py").read_text(encoding="utf-8")
        self.assertNotIn("WalletLedger(", source)
        self.assertNotIn("wallet.coin_balance -=", source)
        self.assertIn("economy_service_client.debit_wallet", source)
        self.assertIn("economy_service_client.credit_wallet", source)

    def test_consumable_purchase_requires_purchase_identity(self):
        source = (ROOT / "backend/app/services/store_service.py").read_text(encoding="utf-8")
        self.assertIn("purchase_id is required for repeatable store purchases", source)
        self.assertIn("StorePurchaseOperation", source)
        self.assertIn("COMPENSATION_PENDING", source)

    def test_flutter_reuses_pending_purchase_id(self):
        source = (
            ROOT
            / "frontend/vibematch_app/lib/features/store/data/store_api_service.dart"
        ).read_text(encoding="utf-8")
        self.assertIn("store_purchase_pending_", source)
        self.assertIn("const Uuid().v4()", source)
        self.assertIn("'purchase_id': purchaseId", source)


if __name__ == "__main__":
    unittest.main()
