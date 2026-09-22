import unittest

from fastapi.routing import APIRoute

from app.api.routes.room_realtime_commands import router
from app.schemas.room_realtime import RoomJoinCommand, RoomWatchPartyCommand
from app.services.rooms.room_action_service import _safe_room_join_event_payload


class RoomRealtimeRestContractTests(unittest.TestCase):
    def test_join_accepts_room_lock_password(self):
        command = RoomJoinCommand(lock_password="secret")
        self.assertEqual("secret", command.lock_password)

    def test_join_event_payload_never_persists_room_password(self):
        payload = _safe_room_join_event_payload(
            {
                "lock_password": "super-secret",
                "password": "legacy-secret",
                "is_stealth": True,
            },
            is_stealth=True,
        )
        self.assertNotIn("lock_password", payload)
        self.assertNotIn("password", payload)
        self.assertTrue(payload["is_stealth"])

    def test_canonical_room_lifecycle_routes_exist(self):
        routes = {
            (route.path, method)
            for route in router.routes
            if isinstance(route, APIRoute)
            for method in route.methods
        }
        prefix = "/rooms/{room_public_id}/realtime"
        self.assertIn((f"{prefix}/snapshot", "GET"), routes)
        self.assertIn((f"{prefix}/join", "POST"), routes)
        self.assertIn((f"{prefix}/heartbeat", "POST"), routes)
        self.assertIn((f"{prefix}/leave", "POST"), routes)
        self.assertIn((f"{prefix}/watch-party/command", "POST"), routes)

    def test_watch_party_command_accepts_revisioned_sync_payload(self):
        command = RoomWatchPartyCommand(
            action="SYNC",
            expected_revision=7,
            position_ms=57340,
            playback_state="playing",
            playback_rate=1.0,
        )
        self.assertEqual("SYNC", command.action)
        self.assertEqual(7, command.expected_revision)


if __name__ == "__main__":
    unittest.main()
