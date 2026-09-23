import json
import unittest
from unittest.mock import patch

from app.services import realtime_revocation_service


class _FakeRealtimeRedis:
    def __init__(self):
        self.published = []

    def publish(self, channel, payload):
        self.published.append((channel, payload))
        return 1


class RealtimeRevocationServiceTests(unittest.TestCase):
    def test_session_revocation_targets_user_and_device(self):
        redis = _FakeRealtimeRedis()
        with patch.object(
            realtime_revocation_service,
            "get_realtime_redis",
            return_value=redis,
        ):
            realtime_revocation_service.publish_session_revoked(
                42,
                reason="session_replaced",
                device_id="device-old",
            )

        self.assertEqual(1, len(redis.published))
        channel, raw = redis.published[0]
        self.assertEqual("funkey:realtime:events", channel)
        envelope = json.loads(raw)
        self.assertEqual("auth.session_revoked", envelope["event_type"])
        self.assertEqual("critical", envelope["priority"])
        self.assertEqual("user", envelope["scope"])
        self.assertEqual(42, envelope["user_id"])
        self.assertEqual("device-old", envelope["payload"]["device_id"])

    def test_room_permission_revocation_supports_user_and_room_scope(self):
        redis = _FakeRealtimeRedis()
        with patch.object(
            realtime_revocation_service,
            "get_realtime_redis",
            return_value=redis,
        ):
            realtime_revocation_service.publish_room_permission_revoked(
                "room-a",
                reason="room_membership_removed",
                membership_version=12,
                user_id=42,
            )
            realtime_revocation_service.publish_room_permission_revoked(
                "room-a",
                reason="room_privacy_changed",
                membership_version=13,
            )

        user_event = json.loads(redis.published[0][1])
        room_event = json.loads(redis.published[1][1])
        self.assertEqual("user", user_event["scope"])
        self.assertEqual(42, user_event["user_id"])
        self.assertEqual("room-a", user_event["payload"]["room_public_id"])
        self.assertEqual(12, user_event["payload"]["membership_version"])
        self.assertEqual("room", room_event["scope"])
        self.assertEqual("room-a", room_event["room_public_id"])
        self.assertEqual(13, room_event["payload"]["membership_version"])


if __name__ == "__main__":
    unittest.main()
