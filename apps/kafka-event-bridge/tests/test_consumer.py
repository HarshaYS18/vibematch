import json
import unittest

from consumer import build_dlq_value


class ConsumerTests(unittest.TestCase):
    def test_dlq_value_has_source_provenance_without_raw_poison_data(self):
        value = build_dlq_value(
            source_topic="funkey.room.events.v1",
            partition=3,
            offset=99,
            reason="ValidationError",
            raw_value=b"x" * 9000,
        )
        decoded = json.loads(value)
        self.assertEqual(decoded["source_partition"], 3)
        self.assertEqual(decoded["source_offset"], 99)
        self.assertEqual(decoded["reason"], "ValidationError")
        self.assertEqual(decoded["raw_bytes"], 9000)
        self.assertEqual(len(decoded["raw_sha256"]), 64)
        self.assertNotIn("raw_utf8", decoded)


if __name__ == "__main__":
    unittest.main()
