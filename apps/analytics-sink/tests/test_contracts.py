import unittest
from datetime import datetime, timezone
from uuid import uuid4

from contracts import AnalyticsEvent


class AnalyticsContractTests(unittest.TestCase):
    def test_event_row_preserves_identity(self):
        event = AnalyticsEvent(
            event_id=uuid4(),
            event_type="room.joined",
            event_version=1,
            schema_version=1,
            occurred_at=datetime.now(timezone.utc),
            published_at=datetime.now(timezone.utc),
            source_service="room-control",
            topic_family="room",
            partition_key="room:R1",
            payload={"room_public_id": "R1"},
        )
        row = event.row()
        self.assertEqual(row["event_id"], str(event.event_id))
        self.assertEqual(row["topic_family"], "room")


if __name__ == "__main__":
    unittest.main()
