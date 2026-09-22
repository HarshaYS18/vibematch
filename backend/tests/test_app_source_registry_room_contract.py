import unittest

from app.services.app_source_registry_service import get_app_source_registry


class AppSourceRegistryRoomContractTests(unittest.TestCase):
    def test_rooms_registry_tracks_canonical_chunk5_contract(self):
        registry = get_app_source_registry()
        room = next(item for item in registry.tabs if item.tab_key == "rooms")

        reads = {item.path for item in room.child_reads}
        writes = {item.path for item in room.child_writes}

        self.assertEqual(4, registry.version)
        self.assertIn(
            "/rooms/{room_public_id}/realtime/snapshot",
            reads,
        )
        for path in {
            "/rooms/{room_public_id}/realtime/join",
            "/rooms/{room_public_id}/realtime/heartbeat",
            "/rooms/{room_public_id}/realtime/leave",
        }:
            self.assertIn(path, writes)

        self.assertIn(
            "/rooms/{room_public_id}/realtime/watch-party/command",
            writes,
        )

        for legacy in {
            "/rooms/{room_public_id}/join",
            "/rooms/{room_public_id}/heartbeat",
            "/rooms/{room_public_id}/leave",
        }:
            self.assertNotIn(legacy, writes)

        self.assertIn("/ws/room-realtime", room.realtime_channels)
        self.assertEqual(
            "canonical_room_session_active",
            room.migration_status,
        )


if __name__ == "__main__":
    unittest.main()
