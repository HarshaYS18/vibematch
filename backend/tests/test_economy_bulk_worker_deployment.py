from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]


class EconomyBulkWorkerDeploymentTests(unittest.TestCase):
    def test_kubernetes_worker_runtime_is_present(self):
        docs = list(
            yaml.safe_load_all(
                (ROOT / "deploy/kubernetes/base/economy.yaml").read_text(
                    encoding="utf-8"
                )
            )
        )
        deployment = next(
            item
            for item in docs
            if item
            and item.get("kind") == "Deployment"
            and item.get("metadata", {}).get("name")
            == "funkey-economy-bulk-worker"
        )
        self.assertEqual(2, deployment["spec"]["replicas"])
        container = deployment["spec"]["template"]["spec"]["containers"][0]
        self.assertEqual(
            ["python", "/app/apps/economy-service/bulk_worker.py"],
            container["command"],
        )
        self.assertEqual(8090, container["ports"][0]["containerPort"])
        self.assertEqual(
            "/ready",
            container["readinessProbe"]["httpGet"]["path"],
        )

    def test_bulk_worker_has_disruption_budget(self):
        docs = list(
            yaml.safe_load_all(
                (ROOT / "deploy/kubernetes/base/economy.yaml").read_text(
                    encoding="utf-8"
                )
            )
        )
        pdb = next(
            item
            for item in docs
            if item
            and item.get("kind") == "PodDisruptionBudget"
            and item.get("metadata", {}).get("name")
            == "funkey-economy-bulk-worker"
        )
        self.assertEqual(1, pdb["spec"]["minAvailable"])

    def test_bulk_worker_hpa_is_bounded(self):
        docs = list(
            yaml.safe_load_all(
                (ROOT / "deploy/kubernetes/base/autoscaling.yaml").read_text(
                    encoding="utf-8"
                )
            )
        )
        hpa = next(
            item
            for item in docs
            if item
            and item.get("kind") == "HorizontalPodAutoscaler"
            and item.get("metadata", {}).get("name")
            == "funkey-economy-bulk-worker"
        )
        self.assertEqual(2, hpa["spec"]["minReplicas"])
        self.assertEqual(4, hpa["spec"]["maxReplicas"])

    def test_compose_worker_uses_bulk_health_port(self):
        source = (ROOT / "infra/docker-compose.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("economy-bulk-worker:", source)
        self.assertIn(
            'command: ["python", "/app/apps/economy-service/bulk_worker.py"]',
            source,
        )
        self.assertIn("127.0.0.1:8090/ready", source)

    def test_production_config_exposes_worker_limits(self):
        source = (ROOT / "deploy/kubernetes/base/config.yaml").read_text(
            encoding="utf-8"
        )
        for token in (
            'ECONOMY_BULK_BATCH_SIZE: "500"',
            'ECONOMY_BULK_WORKER_DB_POOL_SIZE: "2"',
            'ECONOMY_BULK_WORKER_MAX_REPLICAS: "4"',
            'DB_ECONOMY_BULK_WORKER_CONNECTION_BUDGET: "8"',
        ):
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
