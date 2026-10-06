from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class RegularGiftEconomyCutoverTests(unittest.TestCase):
    def test_core_regular_gift_uses_economy_service(self):
        route=(ROOT/"backend/app/api/routes/economy.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.settle_gift",route)
        self.assertIn("experience_service.apply_gift_exp",route)
        self.assertIn("db.commit()",route)

    def test_economy_settles_financial_truth_atomically(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/gifts/settle"',internal)
        self.assertIn("GiftTransaction(",internal)
        self.assertIn("economy_transaction_service.debit(",internal)
        self.assertIn("economy_transaction_service.credit(",internal)
        self.assertIn("economy.gift_settled.v1",internal)
        self.assertNotIn("experience_service.apply_gift_exp",internal)

    def test_gift_client_uses_request_identity(self):
        client=(ROOT/"backend/app/services/economy_service_client.py").read_text(encoding="utf-8")
        self.assertIn('business_reference = f"gift:{sender_user_id}:{request_id}"',client)

if __name__=="__main__":
    unittest.main()
