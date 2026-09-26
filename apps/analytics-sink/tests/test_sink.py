import unittest
from datetime import datetime, timezone
from uuid import UUID

import httpx

from config import Settings
from contracts import AnalyticsEvent
from sink import AnalyticsSink


class SinkTests(unittest.TestCase):
    def settings(self):
        return Settings(
            app_env="development",
            kafka_bootstrap_servers="localhost:9092",
            kafka_security_protocol="PLAINTEXT",
            kafka_username="",
            kafka_password="",
            kafka_group="test",
            clickhouse_url="http://localhost:8123",
            clickhouse_database="funkey_analytics",
            object_store_mode="file",
            object_store_bucket="",
            object_store_prefix="funkey/events/v1",
            object_store_endpoint="",
            object_store_region="ap-south-1",
            object_store_access_key="",
            object_store_secret_key="",
            local_lake_path="/tmp/funkey-test-lake",
            port=8095,
        )

    def event(self, value: int):
        return AnalyticsEvent(
            event_id=UUID(int=value),
            event_type="vibe.viewed",
            event_version=1,
            schema_version=1,
            occurred_at=datetime(2026, 9, 26, tzinfo=timezone.utc),
            published_at=datetime(2026, 9, 26, tzinfo=timezone.utc),
            source_service="vibes",
            topic_family="vibes",
            partition_key="vibe:1",
            payload={"value": value},
        )

    def test_parquet_key_is_deterministic_for_same_event_set(self):
        sink = AnalyticsSink(self.settings(), httpx.AsyncClient())
        first = sink._parquet_batch([self.event(1), self.event(2)])[1]
        second = sink._parquet_batch([self.event(2), self.event(1)])[1]
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
