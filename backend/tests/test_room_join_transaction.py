from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import AsyncMock, Mock, patch

from app.api.routes.rooms import rooms as rooms_route
from app.services.rooms import room_service


class RoomJoinTransactionTests(TestCase):
    def test_join_event_is_recorded_in_authoritative_transaction(self):
        db = Mock()
        room = SimpleNamespace(
            id=3,
            room_public_id="VM123456",
            updated_at=None,
        )

        with patch.object(room_service, "room_sequence", return_value=9):
            room_service._record_join_event(db, room, 7)

        event = db.add.call_args.args[0]
        self.assertEqual(event.room_id, 3)
        self.assertEqual(event.room_public_id, "VM123456")
        self.assertEqual(event.event_type, "room.joined")
        self.assertEqual(event.actor_user_id, 7)
        self.assertEqual(event.sequence, 10)
        self.assertIsNotNone(room.updated_at)
        db.flush.assert_called_once()


class RoomJoinBroadcastTests(IsolatedAsyncioTestCase):
    async def test_rest_join_broadcast_is_read_only(self):
        joined = SimpleNamespace(closed_room_ids=[])
        current_user = SimpleNamespace(id=7, public_user_id=7000007)
        snapshot = {"room_id": "VM123456", "state_version": 10}
        run_in_threadpool = AsyncMock(
            side_effect=[
                (joined, False),
                snapshot,
            ]
        )

        with (
            patch.object(
                rooms_route,
                "run_in_threadpool",
                run_in_threadpool,
            ),
            patch.object(
                rooms_route,
                "_broadcast_closed_room_sessions",
                AsyncMock(),
            ),
            patch.object(
                rooms_route,
                "_record_and_broadcast",
                AsyncMock(),
            ) as record_and_broadcast,
            patch.object(
                rooms_route.room_realtime_connections,
                "broadcast_room",
                AsyncMock(),
            ) as broadcast,
        ):
            result = await rooms_route.join_live_room(
                "VM123456",
                payload=None,
                db=Mock(),
                current_user=current_user,
            )

        self.assertIs(result, joined)
        record_and_broadcast.assert_not_awaited()
        broadcast.assert_awaited_once_with(
            "VM123456",
            {
                "type": "room/joined",
                "payload": {
                    "room_id": "VM123456",
                    "room": snapshot,
                    "target_user_id": 7,
                },
            },
        )


if __name__ == "__main__":
    import unittest

    unittest.main()
