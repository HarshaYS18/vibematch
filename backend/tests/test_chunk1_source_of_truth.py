from datetime import date
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch

from app.api.routes import users as users_route
from app.schemas.user import UserProfileUpdateRequest
from app.services.rooms import room_state_service


class ChunkOneSourceOfTruthTests(TestCase):
    def test_profile_patch_preserves_unspecified_canonical_fields(self):
        current_user = SimpleNamespace(id=7)
        db = Mock()
        payload = UserProfileUpdateRequest(display_name="New Name")

        with (
            patch.object(
                users_route.profile_social_service_client,
                "update_profile",
                return_value={"updated": True, "user_id": 7},
            ) as update_profile,
            patch.object(
                users_route,
                "_user_me_response",
                return_value={"ok": True},
            ) as compose_response,
        ):
            result = users_route.update_my_profile(
                payload,
                db=db,
                current_user=current_user,
            )

        self.assertEqual({"ok": True}, result)
        update_profile.assert_called_once_with(
            user_id=7,
            profile={"display_name": "New Name"},
        )
        db.refresh.assert_called_once_with(current_user)
        compose_response.assert_called_once_with(db, current_user)

    def test_membership_roster_keeps_offline_saved_member(self):
        user = SimpleNamespace(public_user_id=6418001001)
        participant = SimpleNamespace(
            user_id=7,
            user=user,
            is_active=False,
            is_member=True,
            is_room_admin=False,
        )
        room = SimpleNamespace(id=3, owner_user_id=7)
        db = Mock()
        (db.query.return_value.filter.return_value.order_by.return_value.all).return_value = [participant]

        roster = room_state_service.room_membership_roster(db, room)

        self.assertEqual(1, len(roster))
        self.assertEqual(7, roster[0]["backend_user_id"])
        self.assertEqual(6418001001, roster[0]["public_user_id"])
        self.assertTrue(roster[0]["is_room_member"])
        self.assertTrue(roster[0]["is_room_admin"])
        self.assertTrue(roster[0]["is_host"])

    def test_room_snapshot_exposes_membership_roster_separate_from_active_peers(self):
        room = SimpleNamespace(
            id=3,
            room_public_id="VM100",
            owner_user_id=7,
            name="Test Room",
            subtitle=None,
            avatar_url=None,
            cover_photo_url=None,
            language="English",
            mode="Open",
            room_type="Chat",
            online_count=0,
            trending_score=0,
            is_active=True,
            is_secret=False,
            is_locked=False,
            is_members_only=False,
            allow_screenshots=True,
            room_images_enabled=True,
            guest_messages_enabled=True,
            apply_only_mode_enabled=False,
            background_theme_id="default",
            seat_layout_id="5x2",
            announcement_text=None,
            realtime_version=11,
            realtime_event_sequence=13,
            updated_at=None,
        )
        db = Mock()
        db.query.return_value.filter.return_value.order_by.return_value.all.return_value = []
        durable_roster = [{"backend_user_id": 9, "public_user_id": 6418001009, "is_room_member": True}]

        with (
            patch.object(room_state_service, "active_participants", return_value=[]),
            patch.object(room_state_service, "pending_room_member_requests", return_value=[]),
            patch.object(room_state_service, "room_membership_roster", return_value=durable_roster),
            patch.object(room_state_service, "pending_seat_applications", return_value=[]),
            patch.object(room_state_service, "calculate_room_trending_score", return_value=0),
        ):
            snapshot = room_state_service.room_snapshot(db, room, include_chat=False)

        self.assertEqual([], snapshot["peers"])
        self.assertEqual(durable_roster, snapshot["membership_roster"])
        self.assertEqual(11, snapshot["state_version"])
        self.assertEqual(13, snapshot["event_sequence"])


if __name__ == "__main__":
    import unittest

    unittest.main()
