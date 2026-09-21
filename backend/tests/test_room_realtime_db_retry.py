from types import SimpleNamespace
from unittest import TestCase

from sqlalchemy.exc import OperationalError

from app.api.routes.room_realtime import _is_transient_db_lock_error


class RoomRealtimeDbRetryTests(TestCase):
    def _error(self, code: str) -> OperationalError:
        original = SimpleNamespace(sqlstate=code, pgcode=code)
        return OperationalError("statement", {}, original)

    def test_known_lock_errors_are_retryable(self):
        for code in ("40P01", "55P03", "40001"):
            with self.subTest(code=code):
                self.assertTrue(_is_transient_db_lock_error(self._error(code)))

    def test_non_lock_database_errors_are_not_retryable(self):
        for code in ("23505", "23503", "57014"):
            with self.subTest(code=code):
                self.assertFalse(_is_transient_db_lock_error(self._error(code)))


if __name__ == "__main__":
    import unittest

    unittest.main()
