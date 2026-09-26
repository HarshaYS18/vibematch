import unittest

from topics import TOPICS, topic_for_family


class TopicTests(unittest.TestCase):
    def test_catalogue_is_unique_and_retained(self):
        names = [item.name for item in TOPICS]
        families = [item.family for item in TOPICS]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(len(families), len(set(families)))
        for item in TOPICS:
            self.assertGreaterEqual(item.partitions, 12)
            self.assertGreater(item.retention_ms, 0)
            self.assertEqual(item.cleanup_policy, "delete")

    def test_expected_topic_names(self):
        self.assertEqual(topic_for_family("room.events"), "funkey.room.events.v1")
        self.assertEqual(topic_for_family("analytics.dlq"), "funkey.analytics.dlq.v1")


if __name__ == "__main__":
    unittest.main()
