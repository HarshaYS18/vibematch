import unittest

from metrics import render, set_source_lag


class MetricsTests(unittest.TestCase):
    def test_source_lag_gauges_are_exposed_without_entity_labels(self):
        set_source_lag(pending=123, ack_pending=7, redelivered=2)
        payload = render(ready=True, nats_connected=True, kafka_ready=True)
        self.assertIn("funkey_kafka_bridge_source_pending 123", payload)
        self.assertIn("funkey_kafka_bridge_source_ack_pending 7", payload)
        self.assertIn("funkey_kafka_bridge_source_redelivered 2", payload)
        self.assertNotIn("user_id", payload)
        self.assertNotIn("room_id", payload)


if __name__ == "__main__":
    unittest.main()
