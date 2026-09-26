from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]


class EconomyBulkGrantEnqueueApiTests(unittest.TestCase):
    def test_internal_enqueue_api_uses_durable_job_service(self):
        source=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/bulk-grants/enqueue"',source)
        self.assertIn("economy_bulk_grant_service.create_job",source)
        self.assertIn("economy.bulk_grant.queued.v1",source)
        self.assertIn('"eligible_count": int(job.eligible_count)',source)

    def test_shared_client_uses_stable_mutation_identity(self):
        source=(ROOT/"backend/app/services/economy_service_client.py").read_text(encoding="utf-8")
        self.assertIn("def queue_bulk_grant(",source)
        self.assertIn('business_reference = f"bulk-grant:{actor_user_id}:{request_id}"',source)
        self.assertIn('mutation_context("bulk_grant.queue"',source)


if __name__=="__main__":
    unittest.main()
