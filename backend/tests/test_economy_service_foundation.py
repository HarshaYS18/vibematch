from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomyServiceFoundationTests(unittest.TestCase):
    def test_transaction_foundation(self):
        for relative in (
            "backend/app/models/economy_transaction.py",
            "backend/app/services/economy_transaction_service.py",
            "backend/alembic/versions/20260924_0400_economy_service_foundation.py",
        ):
            self.assertTrue((ROOT/relative).exists(), relative)
        source=(ROOT/"backend/app/services/economy_transaction_service.py").read_text(encoding="utf-8")
        for token in ("transaction_id","idempotency_key","business_reference","event_outbox_service.enqueue_event"):
            self.assertIn(token,source)
        self.assertIn("Idempotency key reused with different request",source)

if __name__=="__main__":
    unittest.main()
