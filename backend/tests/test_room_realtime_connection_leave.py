from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock, Mock, patch

from app.api.routes import room_realtime


class RoomRealtimeConnectionLeaveTests(IsolatedAsyncioTestCase):
    async def test_leaving_one_socket_preserves_other_live_session(self):
        websocket = AsyncMock()
        user = SimpleNamespace(id=7)
        db = Mock()
        room = SimpleNamespace(room_public_id="VM123456")
        snapshot = {"state_version": 12}

        with (
            patch.object(
                room_realtime.room_realtime_connections,
                "release_connection",
                AsyncMock(return_value=[("VM123456", 7)]),
            ) as release,
            patch.object(
                room_realtime.room_realtime_connections,
                "has_room_user_connections",
                AsyncMock(return_value=True),
            ),
            patch.object(
                room_realtime,
                "_room_snapshot_for_user",
                return_value=snapshot,
            ),
            patch.object(
                room_realtime,
                "execute_room_command_by_ids",
                AsyncMock(),
            ) as execute,
            patch.object(
                room_realtime,
                "_send_ack",
                AsyncMock(),
            ) as send_ack,
        ):
            should_stop = await room_realtime._leave_current_room_connection(
                websocket,
                room_id="VM123456",
                user=user,
                db=db,
                command_id="cmd-1",
                command_type="room/leave",
                payload={"release_seat": True},
            )

        self.assertTrue(should_stop)
        release.assert_awaited_once_with(websocket)
        execute.assert_not_awaited()
        send_ack.assert_awaited_once()
        websocket.close.assert_awaited_once_with(code=1000)

    async def test_last_socket_leave_deactivates_room_participation(self):
        websocket = AsyncMock()
        user = SimpleNamespace(id=7)
        db = Mock()
        room = SimpleNamespace(room_public_id="VM123456")
        snapshot = {"state_version": 13}

        with (
            patch.object(
                room_realtime.room_realtime_connections,
                "release_connection",
                AsyncMock(return_value=[("VM123456", 7)]),
            ),
            patch.object(
                room_realtime.room_realtime_connections,
                "has_room_user_connections",
                AsyncMock(return_value=False),
            ),
            patch.object(
                room_realtime,
                "execute_room_command_by_ids",
                AsyncMock(return_value=snapshot),
            ) as execute,
            patch.object(
                room_realtime,
                "_send_ack",
                AsyncMock(),
            ),
        ):
            should_stop = await room_realtime._leave_current_room_connection(
                websocket,
                room_id="VM123456",
                user=user,
                db=db,
                command_id="cmd-2",
                command_type="room/leave",
                payload={"release_seat": True},
            )

        self.assertTrue(should_stop)
        execute.assert_awaited_once_with(
            "VM123456",
            7,
            "room/leave",
            {"release_seat": True},
        )
        websocket.close.assert_awaited_once_with(code=1000)


if __name__ == "__main__":
    import unittest

    unittest.main()
