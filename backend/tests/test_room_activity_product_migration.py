import unittest

from fastapi import HTTPException
from fastapi.routing import APIRoute

from app.api.routes.room_realtime_commands import router
from app.schemas.room_realtime import RoomActivityCommand
from app.services.app_source_registry_service import get_app_source_registry
from app.services.rooms.room_activity_service import (
    ROOM_ACTIVITY_KINDS,
    _normalize_kind,
    _safe_metadata,
)


class RoomActivityProductMigrationTests(unittest.TestCase):
    def test_activity_contract_covers_party_karaoke_and_social_games(self):
        self.assertEqual({"party", "karaoke", "social_game"}, set(ROOM_ACTIVITY_KINDS))
        self.assertEqual("karaoke", _normalize_kind("KARAOKE"))
        with self.assertRaises(HTTPException):
            _normalize_kind("watch_party")

    def test_activity_metadata_is_bounded_json(self):
        self.assertEqual({"round": 2}, _safe_metadata({"round": 2}, field_name="metadata"))
        with self.assertRaises(HTTPException):
            _safe_metadata({"bad": object()}, field_name="metadata")
        with self.assertRaises(HTTPException):
            _safe_metadata({"blob": "x" * 9000}, field_name="metadata")

    def test_activity_command_schema_and_route_exist(self):
        command = RoomActivityCommand(
            action="START",
            kind="social_game",
            activity_id="jungle_hunt_party",
            game_id="jungle_hunt",
            metadata={"queue": "room"},
        )
        self.assertEqual("social_game", command.kind)
        routes = {
            (route.path, method)
            for route in router.routes
            if isinstance(route, APIRoute)
            for method in route.methods
        }
        self.assertIn(
            ("/rooms/{room_public_id}/realtime/activity/command", "POST"),
            routes,
        )

    def test_source_registry_keeps_activity_on_room_authority(self):
        registry = get_app_source_registry()
        room = next(item for item in registry.tabs if item.tab_key == "rooms")
        writes = {item.path for item in room.child_writes}
        self.assertGreaterEqual(registry.version, 5)
        self.assertIn("/rooms/{room_public_id}/realtime/activity/command", writes)
        self.assertIn("/ws/room-realtime", room.realtime_channels)


if __name__ == "__main__":
    unittest.main()
