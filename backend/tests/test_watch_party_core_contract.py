import unittest

from fastapi.routing import APIRoute

from app.api.routes.room_realtime_commands import router
from app.schemas.room_realtime import RoomWatchPartyCommand
from app.services.app_source_registry_service import get_app_source_registry
from app.services.rooms.watch_party_service import projected_position_ms


class WatchPartyCoreContractTests(unittest.TestCase):
    def test_server_clock_projection_advances_playing_session(self):
        state = {
            "active": True,
            "playback_state": "playing",
            "position_ms": 52_340,
            "server_anchor_time": 100_000,
            "playback_rate": 1.0,
        }
        self.assertEqual(57_340, projected_position_ms(state, 105_000))

    def test_paused_session_does_not_advance(self):
        state = {
            "active": True,
            "playback_state": "paused",
            "position_ms": 52_340,
            "server_anchor_time": 100_000,
            "playback_rate": 1.0,
        }
        self.assertEqual(52_340, projected_position_ms(state, 105_000))

    def test_watch_party_command_schema_and_route_exist(self):
        command = RoomWatchPartyCommand(
            action="SEEK",
            expected_revision=4,
            position_ms=12_345,
        )
        self.assertEqual("SEEK", command.action)
        self.assertEqual(4, command.expected_revision)

        routes = {
            (route.path, method)
            for route in router.routes
            if isinstance(route, APIRoute)
            for method in route.methods
        }
        self.assertIn(
            ("/rooms/{room_public_id}/realtime/watch-party/command", "POST"),
            routes,
        )

    def test_source_registry_advertises_watch_party_core(self):
        registry = get_app_source_registry()
        room = next(item for item in registry.tabs if item.tab_key == "rooms")
        writes = {item.path for item in room.child_writes}
        self.assertGreaterEqual(registry.version, 4)
        self.assertIn(
            "/rooms/{room_public_id}/realtime/watch-party/command",
            writes,
        )
        self.assertIn("/ws/room-realtime", room.realtime_channels)


if __name__ == "__main__":
    unittest.main()
