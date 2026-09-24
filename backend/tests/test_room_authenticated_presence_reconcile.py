from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch

from app.services.rooms import room_action_service


class AuthenticatedPresenceReconcileTests(TestCase):
    def _db_with_participant(self, participant):
        db = Mock()
        (
            db.query.return_value
            .filter.return_value
            .with_for_update.return_value
            .first
        ).return_value = participant
        return db

    def test_inactive_existing_participant_is_reactivated(self):
        participant = SimpleNamespace(
            is_active=False,
            last_seen_at=None,
            left_at=object(),
        )
        db = self._db_with_participant(participant)
        room = SimpleNamespace(id=3, room_public_id="VM123456")
        user = SimpleNamespace(id=7, last_seen_at=None)

        with (
            patch.object(
                room_action_service,
                "assert_room_entry_allowed",
            ) as entry,
            patch.object(
                room_action_service,
                "user_has_active_room_conflict",
                return_value=False,
            ),
            patch.object(
                room_action_service,
                "mark_user_room_presence_active",
            ) as mark_presence,
        ):
            room_action_service.reconcile_authenticated_room_presence(
                db,
                room,
                user,
            )

        self.assertTrue(participant.is_active)
        self.assertIsNone(participant.left_at)
        self.assertIsNotNone(participant.last_seen_at)
        self.assertIsNone(
            user.last_seen_at,
            "Room Control must not mutate identity-owned users.last_seen_at",
        )
        entry.assert_called_once_with(db, room, user)
        mark_presence.assert_called_once_with(db, room, user)
        db.flush.assert_called_once()

    def test_missing_participant_is_not_created(self):
        db = self._db_with_participant(None)
        room = SimpleNamespace(id=3, room_public_id="VM123456")
        user = SimpleNamespace(id=7)

        with (
            patch.object(
                room_action_service,
                "assert_room_entry_allowed",
            ) as entry,
            patch.object(
                room_action_service,
                "mark_user_room_presence_active",
            ) as mark_presence,
        ):
            room_action_service.reconcile_authenticated_room_presence(
                db,
                room,
                user,
            )

        entry.assert_not_called()
        mark_presence.assert_not_called()
        db.flush.assert_not_called()


if __name__ == "__main__":
    import unittest

    unittest.main()
