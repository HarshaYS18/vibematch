from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from fastapi import HTTPException

from app.services.rooms import room_permission_service as permissions


class RequireJoinTests(TestCase):
    def setUp(self) -> None:
        self.db = object()
        self.room = SimpleNamespace(is_members_only=False)
        self.user = SimpleNamespace(id=42)

    def test_requires_login(self) -> None:
        with self.assertRaises(HTTPException) as raised:
            permissions.require_join(self.db, self.room, None)

        self.assertEqual(raised.exception.status_code, 401)

    @patch.object(permissions, "require_room_view")
    @patch.object(permissions, "participant_for", return_value=None)
    def test_requires_active_participant(self, _participant_for, _room_view) -> None:
        with self.assertRaises(HTTPException) as raised:
            permissions.require_join(self.db, self.room, self.user)

        self.assertEqual(raised.exception.status_code, 409)
        self.assertIn("Join the room", raised.exception.detail)

    @patch.object(permissions, "require_room_view")
    @patch.object(
        permissions,
        "participant_for",
        return_value=SimpleNamespace(
            is_active=False,
            is_member=False,
            is_room_admin=False,
        ),
    )
    def test_rejects_inactive_saved_roster_entry(self, _participant_for, _room_view) -> None:
        with self.assertRaises(HTTPException) as raised:
            permissions.require_join(self.db, self.room, self.user)

        self.assertEqual(raised.exception.status_code, 409)

    @patch.object(permissions, "require_room_view")
    @patch.object(
        permissions,
        "participant_for",
        return_value=SimpleNamespace(
            is_active=True,
            is_member=False,
            is_room_admin=False,
        ),
    )
    def test_allows_active_participant_in_open_room(self, _participant_for, _room_view) -> None:
        permissions.require_join(self.db, self.room, self.user)

    @patch.object(permissions, "is_founder_or_owner", return_value=False)
    @patch.object(permissions, "is_room_owner", return_value=False)
    @patch.object(permissions, "require_room_view")
    @patch.object(
        permissions,
        "participant_for",
        return_value=SimpleNamespace(
            is_active=True,
            is_member=False,
            is_room_admin=False,
        ),
    )
    def test_members_only_room_requires_membership(
        self,
        _participant_for,
        _room_view,
        _is_room_owner,
        _is_founder_or_owner,
    ) -> None:
        self.room.is_members_only = True

        with self.assertRaises(HTTPException) as raised:
            permissions.require_join(self.db, self.room, self.user)

        self.assertEqual(raised.exception.status_code, 403)

    @patch.object(permissions, "is_founder_or_owner", return_value=False)
    @patch.object(permissions, "is_room_owner", return_value=False)
    @patch.object(permissions, "require_room_view")
    @patch.object(
        permissions,
        "participant_for",
        return_value=SimpleNamespace(
            is_active=True,
            is_member=False,
            is_room_admin=True,
        ),
    )
    def test_members_only_room_allows_active_room_admin(
        self,
        _participant_for,
        _room_view,
        _is_room_owner,
        _is_founder_or_owner,
    ) -> None:
        self.room.is_members_only = True

        permissions.require_join(self.db, self.room, self.user)
