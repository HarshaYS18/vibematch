import unittest
from datetime import datetime, timezone
from uuid import uuid4

from contracts import (
    OperationalEventEnvelope,
    build_kafka_envelope,
    partition_key_for,
    sensitive_payload_paths,
    topic_family_for,
)


class ContractTests(unittest.TestCase):
    def event(self, event_type: str, payload: dict):
        return OperationalEventEnvelope(
            event_id=uuid4(),
            event_type=event_type,
            event_version=1,
            occurred_at=datetime.now(timezone.utc),
            payload=payload,
        )

    def test_topic_families(self):
        self.assertEqual(topic_family_for("room.joined"), "room.events")
        self.assertEqual(topic_family_for("vibes.post.published"), "vibes.engagement")
        self.assertEqual(topic_family_for("economy.gift.sent"), "economy.analytics")
        self.assertEqual(topic_family_for("cricket.ball.recorded"), "game.events")
        self.assertEqual(topic_family_for("media.uploaded"), "media.events")
        self.assertEqual(topic_family_for("recommendation.impression"), "recommendation.events")
        self.assertEqual(topic_family_for("identity.login"), "user.activity")
        self.assertIsNone(topic_family_for("notification.requested"))

    def test_partition_key_prefers_domain_key(self):
        event = self.event("room.joined", {"room_public_id": "ROOM-42"})
        self.assertEqual(partition_key_for(event, "room.events"), "ROOM-42")

    def test_sensitive_payload_is_rejected(self):
        event = self.event("user.activity", {"nested": {"access_token": "secret"}})
        self.assertEqual(sensitive_payload_paths(event.payload), ["payload.nested.access_token"])
        with self.assertRaises(ValueError):
            build_kafka_envelope(event)

    def test_analytics_envelope_preserves_event_identity(self):
        event = self.event("media.uploaded", {"media_id": "m1"})
        result = build_kafka_envelope(event)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.event_id, event.event_id)
        self.assertEqual(result.topic_family, "media.events")
        self.assertEqual(result.partition_key, "m1")


if __name__ == "__main__":
    unittest.main()
