from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock, Mock, patch

from sqlalchemy.exc import OperationalError

from app.api.routes import room_realtime


class RoomRealtimeLockRetryTests(IsolatedAsyncioTestCase):
    def _operational_error(self, sqlstate: str) -> OperationalError:
        original = SimpleNamespace(sqlstate=sqlstate, pgcode=sqlstate)
        return OperationalError("statement", {}, original)

    async def test_lock_timeout_is_retried_and_then_succeeds(self):
        db = Mock()
        user = SimpleNamespace(id=7, is_banned=False, is_active=True)
        db.query.return_value.filter.return_value.first.return_value = user
        room = SimpleNamespace(id=3, room_public_id="VM123456")
        expected = {"state_version": 42}
        execute = AsyncMock(
            side_effect=[
                self._operational_error("55P03"),
                expected,
            ]
        )

        with (
            patch.object(room_realtime, "room_or_404", return_value=room),
            patch.object(room_realtime, "execute_room_command", execute),
            patch.object(room_realtime.asyncio, "sleep", AsyncMock()) as sleep,
        ):
            result = await room_realtime._execute_room_command_with_retry(
                db,
                room_id="VM123456",
                user_id=7,
                command_type="seat/take",
                payload={"seat_index": 0},
            )

        self.assertEqual(result, expected)
        self.assertEqual(execute.await_count, 2)
        db.rollback.assert_called_once()
        sleep.assert_awaited_once_with(0.075)

    async def test_non_transient_database_error_is_not_retried(self):
        db = Mock()
        user = SimpleNamespace(id=7, is_banned=False, is_active=True)
        db.query.return_value.filter.return_value.first.return_value = user
        room = SimpleNamespace(id=3, room_public_id="VM123456")
        execute = AsyncMock(side_effect=self._operational_error("23505"))

        with (
            patch.object(room_realtime, "room_or_404", return_value=room),
            patch.object(room_realtime, "execute_room_command", execute),
            patch.object(room_realtime.asyncio, "sleep", AsyncMock()) as sleep,
        ):
            with self.assertRaises(OperationalError):
                await room_realtime._execute_room_command_with_retry(
                    db,
                    room_id="VM123456",
                    user_id=7,
                    command_type="seat/take",
                    payload={"seat_index": 0},
                )

        self.assertEqual(execute.await_count, 1)
        db.rollback.assert_called_once()
        sleep.assert_not_awaited()


if __name__ == "__main__":
    import unittest

    unittest.main()
