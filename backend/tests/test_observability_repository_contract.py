import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class ObservabilityRepositoryContractTests(unittest.TestCase):
    def test_collector_has_bounded_trace_and_log_pipelines(self):
        text = (ROOT / "deploy/observability/otel-collector.yaml").read_text(encoding="utf-8")
        for required in (
            "otel/opentelemetry-collector-contrib:0.161.0",
            "memory_limiter:",
            "batch:",
            "otlphttp/tempo:",
            "otlphttp/loki:",
            "traces:",
            "logs:",
            "sending_queue:",
        ):
            self.assertIn(required, text)

    def test_application_tracing_targets_cluster_collector(self):
        text = (ROOT / "deploy/kubernetes/base/config.yaml").read_text(encoding="utf-8")
        self.assertIn('OTEL_TRACES_ENABLED: "true"', text)
        self.assertIn("funkey-otel-collector.monitoring.svc.cluster.local:4318/v1/traces", text)

    def test_flutter_sentry_keeps_pii_disabled_and_is_optional(self):
        main = (ROOT / "frontend/vibematch_app/lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("sendDefaultPii = false", main)
        self.assertIn("if (dsn.isEmpty) return;", main)
        self.assertLess(main.index("runApp("), main.index("_initializeClientObservability()"))

    def test_observability_runbook_exists(self):
        text = (ROOT / "docs/runbooks/observability-degraded.md").read_text(encoding="utf-8")
        self.assertIn("Do not make application readiness depend", text)
        self.assertIn("OTEL_TRACES_ENABLED=false", text)


if __name__ == "__main__":
    unittest.main()
