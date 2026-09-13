import unittest

from app.realtime.connection_manager import build_global_premium_gift_event


class GlobalPremiumGiftEventTests(unittest.TestCase):
    def test_premium_room_gift_becomes_global_event(self):
        event = {
            "event_id": "socket-event-1",
            "payload": {
                "id": "gift_77_6418000022",
                "event_type": "room_gift_sent",
                "type": "room_gift_sent",
                "message": "room message",
                "show_premium_broadcast": True,
                "broadcast_scope": "room",
            },
        }
        converted = build_global_premium_gift_event("VMGIFT", event)
        self.assertIsNotNone(converted)
        self.assertEqual(converted["event_id"], "socket-event-1")
        payload = converted["payload"]
        self.assertEqual(payload["id"], "gift_77_6418000022")
        self.assertEqual(payload["event_type"], "global_gift_broadcast")
        self.assertEqual(payload["broadcast_scope"], "global")
        self.assertEqual(payload["source_room_id"], "VMGIFT")
        self.assertEqual(payload["message"], "")

    def test_regular_room_gift_is_not_global(self):
        event = {
            "payload": {
                "id": "gift_1",
                "event_type": "room_gift_sent",
                "show_premium_broadcast": False,
            }
        }
        self.assertIsNone(build_global_premium_gift_event("VM1", event))


if __name__ == "__main__":
    unittest.main()
