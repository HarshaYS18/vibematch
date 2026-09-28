from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class LuckyGiftEconomyCutoverTests(unittest.TestCase):
    def test_core_lucky_gift_uses_economy_service(self):
        route=(ROOT/"backend/app/api/routes/economy.py").read_text(encoding="utf-8")
        start=route.index("def _send_lucky_gift_authoritative")
        source=route[start:]
        self.assertIn("economy_service_client.settle_lucky_gift",source)
        self.assertIn("experience_service.apply_gift_exp",source)
        self.assertNotIn("economy_service.send_gift(",source)
        self.assertNotIn("credit_lucky_gift_reward(",source)

    def test_economy_owns_lucky_financial_algorithm(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/gifts/lucky/settle"',internal)
        for token in (
            "record_spend_income",
            "safe_payout_capacity",
            "roll_lucky_gift",
            "record_payout",
            "record_lucky_gift_result",
            "economy.lucky_gift_settled.v1",
        ):
            self.assertIn(token,internal)

if __name__=="__main__":
    unittest.main()
