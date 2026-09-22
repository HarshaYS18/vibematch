from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from app.models.role import RoleName
from app.services.permissions import media_room_permission_service as media_permissions


class MediaRoomPermissionTests(TestCase):
    def setUp(self) -> None:
        self.db = object()
        self.user = SimpleNamespace(id=42, public_user_id="10042")
        self.room = SimpleNamespace(
            id=7,
            room_public_id="ROOM-7",
            owner_user_id=99,
            is_secret=False,
            is_locked=False,
            is_members_only=False,
            apply_only_mode_enabled=False,
        )
        self.participant = SimpleNamespace(is_room_admin=False, is_member=False)

    def _evaluate(self, action: str):
        with (
            patch.object(media_permissions.role_service, "get_primary_role", return_value=RoleName.USER),
            patch.object(media_permissions, "_active_kickout", return_value=None),
        ):
            return media_permissions.evaluate_media_room_permission(
                db=self.db,
                user=self.user,
                room=self.room,
                action=action,
            )

    def test_media_join_requires_active_room_presence(self) -> None:
        with (
            patch.object(media_permissions, "_active_participant", return_value=None),
            patch.object(media_permissions, "_occupied_seat", return_value=None),
        ):
            decision = self._evaluate("join_room")

        self.assertFalse(decision.allowed)
        self.assertIn("Join the room", decision.reason or "")

    def test_active_participant_can_join_media_for_listening(self) -> None:
        with (
            patch.object(media_permissions, "_active_participant", return_value=self.participant),
            patch.object(media_permissions, "_occupied_seat", return_value=None),
        ):
            decision = self._evaluate("join_room")

        self.assertTrue(decision.allowed)
        self.assertIn("CAN_LISTEN", decision.permissions)

    def test_audio_publish_requires_authoritative_seat(self) -> None:
        with (
            patch.object(media_permissions, "_active_participant", return_value=self.participant),
            patch.object(media_permissions, "_occupied_seat", return_value=None),
        ):
            decision = self._evaluate("produce_audio")

        self.assertFalse(decision.allowed)
        self.assertIn("occupied room seat", decision.reason or "")

    def test_approved_seat_can_publish_in_apply_only_room(self) -> None:
        self.room.apply_only_mode_enabled = True
        seat = SimpleNamespace(seat_index=2, admin_muted=False, mic_enabled=True)

        with (
            patch.object(media_permissions, "_active_participant", return_value=self.participant),
            patch.object(media_permissions, "_occupied_seat", return_value=seat),
        ):
            decision = self._evaluate("produce_audio")

        self.assertTrue(decision.allowed)
        self.assertIn("CAN_REQUEST_OR_USE_MIC", decision.permissions)

    def test_admin_muted_user_cannot_publish_audio(self) -> None:
        seat = SimpleNamespace(seat_index=2, admin_muted=True, mic_enabled=True)

        with (
            patch.object(media_permissions, "_active_participant", return_value=self.participant),
            patch.object(media_permissions, "_occupied_seat", return_value=seat),
        ):
            decision = self._evaluate("produce_audio")

        self.assertFalse(decision.allowed)
        self.assertIn("admin-muted", decision.reason or "")


    def test_self_muted_user_cannot_publish_audio(self) -> None:
        seat = SimpleNamespace(
            seat_index=2,
            admin_muted=False,
            mic_enabled=False,
        )

        with (
            patch.object(
                media_permissions,
                "_active_participant",
                return_value=self.participant,
            ),
            patch.object(
                media_permissions,
                "_occupied_seat",
                return_value=seat,
            ),
        ):
            decision = self._evaluate("produce_audio")

        self.assertFalse(decision.allowed)
        self.assertIn("Microphone is muted", decision.reason or "")

    def test_self_muted_user_cannot_resume_audio_producer(self) -> None:
        seat = SimpleNamespace(
            seat_index=2,
            admin_muted=False,
            mic_enabled=False,
        )

        with (
            patch.object(
                media_permissions,
                "_active_participant",
                return_value=self.participant,
            ),
            patch.object(
                media_permissions,
                "_occupied_seat",
                return_value=seat,
            ),
        ):
            decision = self._evaluate("resume_producer")

        self.assertFalse(decision.allowed)
        self.assertIn("Microphone is muted", decision.reason or "")
