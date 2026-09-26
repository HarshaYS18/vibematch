from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

from app.models.call_session import CallParticipantStatus, CallSessionStatus, CallSessionType
from app.models.role import RoleName
from app.services import call_session_service
from app.services import media_realtime_auth_service as auth


class CallMediaPermissionsTests(TestCase):
    def verify(self, *, action="join_room", joined=True, active=True, video=False):
        user = SimpleNamespace(id=1, public_user_id=10001, username="u", display_name="U", avatar_url=None, is_active=True, is_banned=False)
        call = SimpleNamespace(id=2, status=CallSessionStatus.ACTIVE if active else CallSessionStatus.ENDED, is_video_enabled=video)
        participant = SimpleNamespace(status=CallParticipantStatus.JOINED if joined else CallParticipantStatus.INVITED)
        db = MagicMock()
        db.query.return_value.filter.return_value.first.side_effect = [call, participant]
        with patch.object(auth.ban_service, "is_device_banned", return_value=False), patch.object(auth.role_service, "get_user_roles", return_value=[RoleName.USER]), patch.object(auth.role_service, "get_primary_role", return_value=RoleName.USER):
            return auth.verify_media_realtime_request(db=db, user=user, room_public_id="call_room_test", requested_action=action)

    def test_only_joined_active_call_participants_get_media(self):
        self.assertTrue(self.verify()["allowed"])
        self.assertFalse(self.verify(joined=False)["allowed"])
        self.assertFalse(self.verify(active=False)["allowed"])

    def test_calls_cannot_control_room_seats_or_music(self):
        for action in ["join_seat", "leave_seat", "start_room_music", "stop_room_music"]:
            self.assertFalse(self.verify(action=action)["allowed"])

    def test_video_requires_video_call(self):
        self.assertFalse(self.verify(action="produce_video")["allowed"])
        self.assertTrue(self.verify(action="produce_video", video=True)["allowed"])


class CallSessionNamespaceTests(TestCase):
    def test_general_calls_generate_media_namespace_when_room_is_absent(self):
        db = MagicMock()
        actor = SimpleNamespace(id=1)
        session = call_session_service.create_call_session(
            db=db,
            actor=actor,
            participant_user_ids=[2],
            call_type=CallSessionType.DIRECT_AUDIO,
        )
        self.assertTrue(session.room_public_id.startswith("call_room_"))

    def test_client_cannot_claim_server_call_namespace(self):
        db = MagicMock()
        actor = SimpleNamespace(id=1)
        with self.assertRaises(HTTPException) as raised:
            call_session_service.create_call_session(
                db=db,
                actor=actor,
                participant_user_ids=[2],
                call_type=CallSessionType.DIRECT_AUDIO,
                room_public_id="call_room_client_supplied",
            )
        self.assertEqual(400, raised.exception.status_code)
