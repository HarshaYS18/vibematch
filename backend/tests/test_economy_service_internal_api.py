from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomyInternalApiTests(unittest.TestCase):
    def test_internal_only_runtime_exists(self):
        main=(ROOT/"apps/economy-service/main.py").read_text(encoding="utf-8")
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn("app.include_router(internal_router)",main)
        self.assertNotIn("economy.router",main)
        for route in (
            '/wallet/debit',
            '/wallet/credit',
            '/mission-rewards/claim',
            '/game/wager',
            '/game/settle',
        ):
            self.assertIn(route,internal)

    def test_game_settlement_preserves_financial_safety(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        for token in (
            "cap_reward_by_house_rules",
            "cap_reward_by_whale_rules",
            "record_house_profit_or_loss",
            "economy.game_settled.v1",
        ):
            self.assertIn(token,internal)

    def test_transaction_id_cannot_alias_another_idempotency_key(self):
        tx=(ROOT/"backend/app/services/economy_transaction_service.py").read_text(encoding="utf-8")
        self.assertIn("transaction_id is already bound to another idempotency key",tx)

if __name__=="__main__":
    unittest.main()
