import unittest

from app.services import experience_service


class SocialMissionContractTests(unittest.TestCase):
    def test_social_missions_have_bounded_rewards_and_existing_domain_sources(self):
        definitions = experience_service._SOCIAL_MISSIONS
        self.assertEqual(
            {"join_room", "take_stage", "room_activity", "send_gift"},
            {item["id"] for item in definitions},
        )
        self.assertTrue(all(int(item["reward_coins"]) > 0 for item in definitions))
        event_types = {
            event
            for item in definitions
            for event in item["event_types"]
        }
        self.assertIn("room.joined", event_types)
        self.assertIn("seat.taken", event_types)
        self.assertIn("room_activity.state.started", event_types)

    def test_cycle_key_is_stable_daily_key(self):
        from datetime import datetime
        first = experience_service.social_mission_cycle_key(datetime(2026, 9, 23, 1, 0, 0))
        second = experience_service.social_mission_cycle_key(datetime(2026, 9, 23, 23, 59, 59))
        self.assertEqual("2026-09-23", first)
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
