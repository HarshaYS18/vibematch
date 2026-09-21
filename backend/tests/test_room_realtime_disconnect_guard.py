from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest import TestCase

from app.api.routes.room_realtime import _disconnect_is_superseded


class RoomRealtimeDisconnectGuardTests(TestCase):
    def test_newer_join_supersedes_stale_disconnect(self):
        disconnected_at = datetime.utcnow()
        participant = SimpleNamespace(
            last_seen_at=disconnected_at + timedelta(milliseconds=1)
        )
        self.assertTrue(
            _disconnect_is_superseded(participant, disconnected_at)
        )

    def test_old_or_missing_last_seen_does_not_supersede_disconnect(self):
        disconnected_at = datetime.utcnow()
        older = SimpleNamespace(
            last_seen_at=disconnected_at - timedelta(milliseconds=1)
        )
        same = SimpleNamespace(last_seen_at=disconnected_at)
        missing = SimpleNamespace(last_seen_at=None)

        self.assertFalse(_disconnect_is_superseded(older, disconnected_at))
        self.assertFalse(_disconnect_is_superseded(same, disconnected_at))
        self.assertFalse(_disconnect_is_superseded(missing, disconnected_at))


if __name__ == "__main__":
    import unittest

    unittest.main()
