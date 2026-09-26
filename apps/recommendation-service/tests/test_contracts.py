import unittest
from datetime import datetime, timezone
from uuid import uuid4

from contracts import KafkaEvent, signal_from_event


class ContractTests(unittest.TestCase):
    def test_explicit_signal(self):
        event = KafkaEvent(
            event_id=uuid4(),
            event_type="recommendation.signal",
            event_version=1,
            occurred_at=datetime.now(timezone.utc),
            payload={
                "recommendation_signal": {
                    "public_user_id": "U1",
                    "candidate_id": "R1",
                    "candidate_kind": "room",
                    "action": "join",
                    "weight": 4.0,
                }
            },
        )
        signal = signal_from_event(event)
        self.assertIsNotNone(signal)
        assert signal is not None
        self.assertEqual(signal.member, "room:R1")


if __name__ == "__main__":
    unittest.main()
