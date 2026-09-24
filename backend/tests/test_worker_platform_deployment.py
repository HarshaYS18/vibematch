from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class WorkerPlatformDeploymentTests(unittest.TestCase):
    def test_pool_deployments_exist(self):
        manifest=(ROOT/"deploy/kubernetes/base/worker.yaml").read_text(encoding="utf-8")
        for pool in ("general","notification","media","fanout","maintenance","analytics"):
            self.assertIn(f"value: {pool}",manifest)
        self.assertIn("replicas: 0",manifest)
    def test_keda_uses_pool_consumers(self):
        scaling=(ROOT/"deploy/kubernetes/base/autoscaling.yaml").read_text(encoding="utf-8")
        for consumer in ("funkey-worker-notification","funkey-worker-fanout","funkey-worker-media-moderation","funkey-worker-media-delete","funkey-worker-maintenance-backup","funkey-worker-maintenance-restore","funkey-worker-maintenance-media-cleanup"):
            self.assertIn(consumer,scaling)
        self.assertNotIn("consumer: funkey-worker\n",scaling)
    def test_docs_cover_dlq_drain_and_dormant_analytics(self):
        readme=(ROOT/"docs/modules/worker/README.md").read_text(encoding="utf-8")
        runbook=(ROOT/"docs/runbooks/worker-platform.md").read_text(encoding="utf-8")
        self.assertIn("DLQ",readme)
        self.assertIn("drain NATS",runbook)
        self.assertIn("analytics",readme)

if __name__=="__main__": unittest.main()
