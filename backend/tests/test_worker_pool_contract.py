from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class WorkerPoolContractTests(unittest.TestCase):
    def test_required_pools_exist(self):
        source=(ROOT/"apps/worker/pools.py").read_text(encoding="utf-8")
        for name in ('"general"','"notification"','"media"','"fanout"','"maintenance"','"analytics"'):
            self.assertIn(name,source)
    def test_general_is_only_outbox_relay(self):
        source=(ROOT/"apps/worker/pools.py").read_text(encoding="utf-8")
        self.assertIn('PoolSpec("general", (), frozenset(), relay_outbox=True',source)
    def test_existing_events_have_one_pool(self):
        source=(ROOT/"apps/worker/pools.py").read_text(encoding="utf-8")
        for event in ('"notification.requested"','"vibes.post.published"','"vibes.media.requested"'):
            self.assertEqual(source.count(event),1)
    def test_unimplemented_events_are_not_silently_acked(self):
        source=(ROOT/"apps/worker/main.py").read_text(encoding="utf-8")
        self.assertIn("unsupported_pool_event",source)
        self.assertIn("missing_handler",source)
        self.assertIn("funkey.dlq.",source)
    def test_pool_concurrency_is_bounded(self):
        source=(ROOT/"apps/worker/main.py").read_text(encoding="utf-8")
        self.assertIn("POOL.max_in_flight",source)
        self.assertIn("max_ack_pending",source)

if __name__=="__main__": unittest.main()
