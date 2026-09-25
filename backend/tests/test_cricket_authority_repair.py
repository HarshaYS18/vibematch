from pathlib import Path
from unittest import TestCase
from unittest.mock import Mock, patch

from app.services.rooms import cricket_service


ROOT = Path(__file__).resolve().parents[2]


class CricketAuthorityRepairTests(TestCase):
    def test_room_guard_enforces_admin_for_mutation(self):
        db = Mock()
        user = Mock(id=7)
        room = Mock(id=3, room_public_id="VM123")
        with (
            patch.object(cricket_service, "get_room_model_by_public_id", return_value=room),
            patch.object(
                cricket_service.room_permission_service,
                "require_room_admin",
            ) as require_admin,
            patch.object(
                cricket_service.room_permission_service,
                "require_room_view",
            ) as require_view,
        ):
            resolved = cricket_service._require_room(
                db,
                "VM123",
                user,
                admin=True,
            )
        self.assertIs(resolved, room)
        require_admin.assert_called_once_with(db, room, user)
        require_view.assert_not_called()

    def test_room_guard_enforces_view_permission_for_reads(self):
        db = Mock()
        user = Mock(id=7)
        room = Mock(id=3, room_public_id="VM123")
        with (
            patch.object(cricket_service, "get_room_model_by_public_id", return_value=room),
            patch.object(
                cricket_service.room_permission_service,
                "require_room_admin",
            ) as require_admin,
            patch.object(
                cricket_service.room_permission_service,
                "require_room_view",
            ) as require_view,
        ):
            resolved = cricket_service._require_room(
                db,
                "VM123",
                user,
                admin=False,
            )
        self.assertIs(resolved, room)
        require_view.assert_called_once_with(db, room, user)
        require_admin.assert_not_called()

    def test_cricket_permission_guard_uses_room_model_not_response_dto(self):
        source = (
            ROOT / "backend/app/services/rooms/cricket_service.py"
        ).read_text(encoding="utf-8")
        self.assertIn("get_room_model_by_public_id", source)
        self.assertNotIn("get_room_by_public_id", source)

    def test_core_cricket_routes_are_proxy_only(self):
        source = (
            ROOT / "backend/app/api/routes/rooms/cricket.py"
        ).read_text(encoding="utf-8")
        self.assertIn("room_control_service_client.execute_cricket_operation", source)
        self.assertNotIn("Depends(get_db)", source)
        self.assertNotIn("services.rooms.cricket_service", source)

    def test_cricket_scoring_is_normalized_and_serialized(self):
        service = (
            ROOT / "backend/app/services/rooms/cricket_service.py"
        ).read_text(encoding="utf-8")
        model = (
            ROOT / "backend/app/models/cricket.py"
        ).read_text(encoding="utf-8")
        self.assertIn("with_for_update()", service)
        self.assertIn("CricketBallEvent(", service)
        self.assertIn("func.max(CricketBallEvent.sequence)", service)
        self.assertNotIn("events.append(event)", service)
        self.assertIn(
            'name="uq_cricket_ball_event_match_sequence"',
            model,
        )

    def test_room_control_owns_all_cricket_tables(self):
        ownership = (
            ROOT / "deploy/postgres/room-control-ownership.sql"
        ).read_text(encoding="utf-8")
        for table in (
            "cricket_tournaments",
            "cricket_matches",
            "cricket_ball_events",
        ):
            self.assertIn(
                f"ALTER TABLE {table} OWNER TO funkey_room_control_owner",
                ownership,
            )
        self.assertIn("funkey_room_control_reader", ownership)


if __name__ == "__main__":
    import unittest

    unittest.main()
