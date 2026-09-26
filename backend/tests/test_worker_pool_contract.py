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
    def test_pool_concurrency_is_bounded_across_all_subscriptions(self):
        source=(ROOT/"apps/worker/main.py").read_text(encoding="utf-8")
        self.assertIn(
            "slots = asyncio.Semaphore(max(1, POOL.max_in_flight))",
            source,
        )
        self.assertIn("async with slots:",source)
        self.assertIn("consume(js, subscription, stop, slots)",source)
        self.assertIn("max_ack_pending",source)

    def test_dormant_pool_fails_closed(self):
        source=(ROOT/"apps/worker/main.py").read_text(encoding="utf-8")
        self.assertIn("if not POOL.active:",source)
        self.assertIn("intentionally inactive",source)

    def test_shutdown_grace_is_bounded(self):
        source=(ROOT/"apps/worker/main.py").read_text(encoding="utf-8")
        self.assertIn("300.0",source)
        self.assertIn("5.0",source)

if __name__=="__main__": unittest.main()
