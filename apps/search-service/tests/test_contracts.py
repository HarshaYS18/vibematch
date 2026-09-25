import unittest
from datetime import datetime, timezone
from uuid import uuid4

from contracts import EventEnvelope, projection_from_event


class SearchContractTests(unittest.TestCase):
    def test_projection_is_explicit_and_versioned(self):
        event = EventEnvelope(
            event_id=uuid4(),
            event_type="profile.updated",
            event_version=1,
            occurred_at=datetime.now(timezone.utc),
            payload={
                "search_projection": {
                    "kind": "user",
                    "public_id": "U1",
                    "title": "Alice",
                    "keywords": ["alice"],
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            },
        )
        doc = projection_from_event(event)
        self.assertIsNotNone(doc)
        assert doc is not None
        self.assertEqual(doc.kind, "user")
        self.assertEqual(doc.public_id, "U1")

    def test_unrelated_event_is_ignored(self):
        event = EventEnvelope(
            event_id=uuid4(),
            event_type="economy.balance.changed",
            event_version=1,
            occurred_at=datetime.now(timezone.utc),
            payload={},
        )
        self.assertIsNone(projection_from_event(event))


if __name__ == "__main__":
    unittest.main()
