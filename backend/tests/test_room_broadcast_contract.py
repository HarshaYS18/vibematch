import inspect
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch

from app.api.routes.rooms import rooms as rooms_route
from app.api.routes.rooms.rooms import _record_and_broadcast, _record_event_snapshot


class RoomBroadcastContractTests(TestCase):
    def test_record_and_broadcast_requires_wire_type(self):
        signature = inspect.signature(_record_and_broadcast)
        self.assertIn("wire_type", signature.parameters)
        self.assertEqual(
            signature.parameters["wire_type"].kind,
            inspect.Parameter.KEYWORD_ONLY,
        )

    def test_snapshot_helper_does_not_require_wire_type(self):
        signature = inspect.signature(_record_event_snapshot)
        self.assertNotIn("wire_type", signature.parameters)

    def test_snapshot_helper_executes_without_wire_type(self):
        db = Mock()
        room = SimpleNamespace(id=1, room_public_id="VM123456")
        snapshot = {"room_id": "VM123456", "state_version": 1}

        with (
            patch.object(rooms_route, "_locked_room", return_value=room),
            patch.object(rooms_route.room_action_service, "record_room_event") as record,
            patch.object(rooms_route, "client_room_snapshot", return_value=snapshot),
        ):
            room_id, returned_snapshot, payload = _record_event_snapshot(
                db,
                room,
                event_type="room.joined",
                actor_user_id=7,
            )

        self.assertEqual(room_id, "VM123456")
        self.assertEqual(returned_snapshot, snapshot)
        self.assertEqual(
            payload,
            {"room_id": "VM123456", "room": snapshot},
        )
        record.assert_called_once_with(
            db,
            room,
            "room.joined",
            actor_user_id=7,
            target_user_id=None,
            payload=None,
        )


if __name__ == "__main__":
    import unittest

    unittest.main()
