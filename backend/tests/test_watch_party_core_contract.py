import unittest

from fastapi import HTTPException
from fastapi.routing import APIRoute

from app.api.routes.room_realtime_commands import router
from app.schemas.room_realtime import RoomWatchPartyCommand
from app.services.app_source_registry_service import get_app_source_registry
from app.models.room import Room
from app.services.rooms.watch_party_service import (
    DEFAULT_TARGET_LIVE_LATENCY_MS,
    _require_private_ott_room,
    _timeline_fields,
    canonical_provider_id,
    is_ott_provider,
    projected_position_ms,
)


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

    def test_ott_provider_ids_are_canonical(self):
        self.assertEqual("prime_video", canonical_provider_id("Prime Video"))
        self.assertEqual("jiohotstar", canonical_provider_id("hotstar"))
        self.assertTrue(is_ott_provider("Netflix"))
        self.assertFalse(is_ott_provider("youtube"))

    def test_ott_requires_invite_only_secret_vibe_room(self):
        private_room = Room(is_secret=True)
        public_room = Room(is_secret=False)
        _require_private_ott_room(private_room, "netflix")
        _require_private_ott_room(public_room, "youtube")
        with self.assertRaises(HTTPException) as caught:
            _require_private_ott_room(public_room, "prime_video")
        self.assertEqual(403, caught.exception.status_code)

    def test_live_timeline_metadata_is_validated(self):
        fields = _timeline_fields({"timeline_mode": "live"})
        self.assertEqual("live", fields["timeline_mode"])
        self.assertEqual(
            DEFAULT_TARGET_LIVE_LATENCY_MS,
            fields["target_live_latency_ms"],
        )
        with self.assertRaises(HTTPException):
            _timeline_fields(
                {"timeline_mode": "live", "target_live_latency_ms": 250}
            )

    def test_watch_party_command_schema_and_route_exist(self):
        command = RoomWatchPartyCommand(
            action="SEEK",
            expected_revision=4,
            position_ms=12_345,
        )
        self.assertEqual("SEEK", command.action)
        self.assertEqual(4, command.expected_revision)

        live_command = RoomWatchPartyCommand(
            action="LOAD",
            provider="jiohotstar",
            content_url="https://www.jiohotstar.com/",
            timeline_mode="live",
            target_live_latency_ms=10_000,
        )
        self.assertEqual("live", live_command.timeline_mode)
        self.assertEqual(10_000, live_command.target_live_latency_ms)

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
        self.assertIn("/ws", room.realtime_channels)


if __name__ == "__main__":
    unittest.main()
