import unittest
from datetime import datetime, timezone, timedelta

from replay import parse_utc, validate_destination, validate_window


class ReplayTests(unittest.TestCase):
    def test_parse_requires_timezone(self):
        with self.assertRaises(ValueError):
            parse_utc("2026-09-01T00:00:00")

    def test_destination_namespace_is_isolated(self):
        validate_destination("funkey.room.events.v1", "funkey.replay.room.events.test")
        with self.assertRaises(ValueError):
            validate_destination("funkey.room.events.v1", "funkey.room.events.v1")
        with self.assertRaises(ValueError):
            validate_destination("funkey.room.events.v1", "funkey.game.events.v1")

    def test_window_is_bounded(self):
        start = datetime(2026, 9, 1, tzinfo=timezone.utc)
        validate_window(start, start + timedelta(days=1))
        with self.assertRaises(ValueError):
            validate_window(start, start + timedelta(days=32))
        with self.assertRaises(ValueError):
            validate_window(start, start)


if __name__ == "__main__":
    unittest.main()
