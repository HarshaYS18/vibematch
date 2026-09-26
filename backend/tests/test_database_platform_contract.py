from pathlib import Path
from unittest import TestCase

from app.core.operational import statement_fingerprint


ROOT = Path(__file__).resolve().parents[2]


class DatabasePlatformContractTests(TestCase):
    def test_pgbouncer_is_transaction_pooled_and_bounded(self):
        manifest = (ROOT / "deploy/postgres/pgbouncer.yaml").read_text(encoding="utf-8")
        self.assertIn("image: pgbouncer/pgbouncer:1.25.2", manifest)
        self.assertIn("PGBOUNCER_POOL_MODE, value: transaction", manifest)
        self.assertIn("PGBOUNCER_MAX_CLIENT_CONN", manifest)
        self.assertIn("DATABASES_MAX_DB_CONNECTIONS", manifest)
        self.assertIn("PGBOUNCER_AUTH_TYPE, value: scram-sha-256", manifest)
        self.assertIn("funkey-pgbouncer-auth", manifest)

    def test_postgres_exporter_enables_required_collectors_without_query_text(self):
        manifest = (ROOT / "deploy/postgres/postgres-exporter.yaml").read_text(encoding="utf-8")
        self.assertIn("postgres-exporter:v0.20.1", manifest)
        self.assertIn("--collector.locks", manifest)
        self.assertIn("--collector.stat_statements", manifest)
        self.assertIn("--collector.long_running_transactions", manifest)
        self.assertNotIn("stat_statements.include_query", manifest)
        self.assertIn("funkey-postgres-monitoring", manifest)

    def test_local_runtime_uses_pooler_but_migrations_remain_direct(self):
        compose = (ROOT / "infra/docker-compose.yml").read_text(encoding="utf-8")
        self.assertIn("database_url: postgresql://funkey:funkey_dev_only@pgbouncer:6432/funkey", compose)
        self.assertIn("MIGRATION_DATABASE_URL: postgresql://funkey:funkey_dev_only@postgres:5432/funkey", compose)
        self.assertIn("DB_POOLER_MODE: transaction", compose)
        bootstrap = (ROOT / "infra/postgres/init/00-platform.sql").read_text(encoding="utf-8")
        self.assertIn("CREATE EXTENSION IF NOT EXISTS pg_stat_statements", bootstrap)
        self.assertIn("idle_in_transaction_session_timeout", bootstrap)

    def test_slow_query_fingerprint_does_not_expose_statement(self):
        statement = "SELECT * FROM private_messages WHERE body = 'secret text'"
        fingerprint = statement_fingerprint(statement)
        self.assertEqual(16, len(fingerprint))
        self.assertNotIn("secret", fingerprint)
        self.assertNotEqual(statement, fingerprint)

    def test_operational_alerts_cover_pool_deadlock_locks_and_long_transactions(self):
        rules = (ROOT / "deploy/observability/prometheus-rules.yaml").read_text(encoding="utf-8")
        for alert in (
            "FunKeyDatabasePoolSaturated",
            "FunKeySlowQueryBurst",
            "FunKeyPostgresConnectionsNearLimit",
            "FunKeyPostgresDeadlock",
            "FunKeyPostgresLongRunningTransaction",
            "FunKeyPostgresLockPressure",
        ):
            self.assertIn(alert, rules)
