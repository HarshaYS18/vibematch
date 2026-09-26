from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomyBulkGrantWorkerTests(unittest.TestCase):
    def test_bulk_grant_is_resumable_and_batched(self):
        service=(ROOT/"backend/app/services/economy_bulk_grant_service.py").read_text(encoding="utf-8")
        for token in (
            "max_user_id",
            "last_user_id",
            "with_for_update(skip_locked=True)",
            "EconomyBulkGrantRecipient",
            'source_type="SUPER_OWNER_SEND_ALL"',
            "economy.bulk_grant.completed.v1",
            "next_attempt_at",
        ):
            self.assertIn(token,service)

    def test_worker_has_separate_bounded_db_pool_and_health(self):
        worker=(ROOT/"apps/economy-service/bulk_worker.py").read_text(encoding="utf-8")
        database=(ROOT/"apps/economy-service/bulk_database.py").read_text(encoding="utf-8")
        self.assertIn("validate_economy_bulk_worker",worker)
        self.assertIn('"/ready"',worker)
        self.assertIn("ECONOMY_BULK_WORKER_DB_POOL_SIZE",database)

    def test_bulk_worker_capacity_is_in_pooler_budget(self):
        config=(ROOT/"backend/app/core/config.py").read_text(encoding="utf-8")
        self.assertIn("DB_ECONOMY_BULK_WORKER_CONNECTION_BUDGET",config)
        self.assertIn("+ self.DB_ECONOMY_BULK_WORKER_CONNECTION_BUDGET",config)

if __name__=="__main__":
    unittest.main()
