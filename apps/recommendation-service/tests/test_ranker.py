import unittest
from datetime import datetime, timedelta, timezone

from contracts import RecommendationSignal
from ranker import decayed_weight, score


class RankerTests(unittest.TestCase):
    def signal(self, action="join", weight=4.0, age_hours=0):
        return RecommendationSignal(
            public_user_id="U1",
            candidate_id="R1",
            candidate_kind="room",
            action=action,
            weight=weight,
            occurred_at=datetime.now(timezone.utc) - timedelta(hours=age_hours),
        )

    def test_recent_signal_outranks_old_signal(self):
        now = datetime.now(timezone.utc)
        recent = self.signal(age_hours=0)
        old = self.signal(age_hours=12)
        self.assertGreater(decayed_weight(recent, now=now), decayed_weight(old, now=now))

    def test_score_is_deterministic_for_same_time(self):
        now = datetime.now(timezone.utc)
        signal = self.signal()
        self.assertEqual(score(signal, now=now), score(signal, now=now))


if __name__ == "__main__":
    unittest.main()
