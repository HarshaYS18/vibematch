from __future__ import annotations

import json
from pathlib import Path
from unittest import TestCase
from unittest.mock import patch

from app.api.routes.room_cross_domain import _debit_theme_once
from app.models.user import User


ROOT = Path(__file__).resolve().parents[2]


class RoomControlServiceContractTests(TestCase):
    def test_core_mounts_proxy_and_not_room_authority(self):
        router = (ROOT / "backend" / "app" / "api" / "router.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("room_control_proxy.router", router)
        self.assertIn("room_control_proxy.admin_router", router)
        self.assertIn("room_cross_domain.router", router)
        self.assertNotIn("rooms.router", router)
        self.assertNotIn("rooms.admin_router", router)
        self.assertNotIn("room_realtime_commands.router", router)

    def test_room_command_background_transactions_use_room_session(self):
        commands = (
            ROOT / "backend" / "app" / "api" / "routes" /
            "room_realtime_commands.py"
        ).read_text(encoding="utf-8")
        rooms = (
            ROOT / "backend" / "app" / "api" / "routes" /
            "rooms" / "rooms.py"
        ).read_text(encoding="utf-8")
        self.assertNotIn("SessionLocal", commands)
        self.assertIn("with room_session() as db:", commands)
        self.assertIn("with room_session() as snapshot_db:", rooms)

    def test_room_theme_service_has_no_economy_write_authority(self):
        source = (
            ROOT / "backend" / "app" / "services" / "rooms" /
            "room_theme_service.py"
        ).read_text(encoding="utf-8")
        for forbidden in (
            "UserWallet",
            "WalletLedger",
            "EconomyCurrency",
            "EconomyDirection",
        ):
            self.assertNotIn(forbidden, source)
        self.assertIn("room_theme_purchase_quote", source)
        self.assertIn("grant_room_theme_inventory", source)

    def test_theme_debit_uses_stable_economy_business_reference(self):
        user = User(id=1, public_user_id=6418000000001, username="buyer")
        with patch(
            "app.api.routes.room_cross_domain.economy_service_client.debit_wallet"
        ) as debit:
            _debit_theme_once(
                user=user,
                theme_id="royal_stage",
                theme_name="Royal Stage",
                price=250,
            )
            _debit_theme_once(
                user=user,
                theme_id="royal_stage",
                theme_name="Royal Stage",
                price=250,
            )

        self.assertEqual(2, debit.call_count)
        for call in debit.call_args_list:
            self.assertEqual(1, call.kwargs["user_id"])
            self.assertEqual(250, call.kwargs["amount"])
            self.assertEqual("ROOM_THEME_PURCHASE", call.kwargs["source_type"])
            self.assertEqual("royal_stage", call.kwargs["source_id"])
            self.assertEqual("room_theme.purchase", call.kwargs["operation"])
            self.assertEqual(
                "room-theme-purchase:1:royal_stage",
                call.kwargs["business_reference"],
            )


    def test_room_owned_tables_have_isolated_runtime_role(self):
        sql = (
            ROOT / "deploy" / "postgres" / "room-control-ownership.sql"
        ).read_text(encoding="utf-8")
        for table in (
            "rooms",
            "room_participants",
            "room_seat_states",
            "room_realtime_events",
            "room_member_requests",
            "room_seat_applications",
            "room_chat_messages",
            "room_kickouts",
            "room_themes",
            "user_room_theme_inventory",
            "room_theme_reviews",
        ):
            self.assertIn(
                f"ALTER TABLE {table} OWNER TO funkey_room_control_owner",
                sql,
            )
        self.assertIn(
            "GRANT SELECT, INSERT, UPDATE ON TABLE user_room_presence",
            sql,
        )
        self.assertIn("GRANT INSERT ON TABLE event_outbox", sql)

    def test_core_realtime_and_media_do_not_bypass_room_control(self):
        realtime = (
            ROOT / "backend" / "app" / "api" / "routes" /
            "realtime_gateway_auth.py"
        ).read_text(encoding="utf-8")
        media = (
            ROOT / "backend" / "app" / "services" /
            "media_realtime_auth_service.py"
        ).read_text(encoding="utf-8")
        internal = (
            ROOT / "apps" / "room-control-service" / "internal.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "room_control_service_client.authorize_room_action",
            realtime,
        )
        self.assertIn(
            "room_control_service_client.execute_realtime_command",
            realtime,
        )
        self.assertNotIn("from app.models.room import Room", realtime)
        self.assertNotIn("evaluate_media_room_permission(", realtime)
        self.assertNotIn("db.query(Room)", realtime)

        self.assertIn(
            "room_control_service_client.authorize_room_action",
            media,
        )
        self.assertNotIn("from app.models.room import Room", media)
        self.assertNotIn("evaluate_media_room_permission(", media)
        self.assertNotIn("db.query(Room)", media)

        self.assertIn('"/authorize"', internal)
        self.assertIn('"/command"', internal)
        self.assertIn("evaluate_media_room_permission(", internal)
        self.assertIn("execute_application_realtime_command(", internal)

    def test_all_room_authorities_point_to_room_control(self):
        payload = json.loads(
            (
                ROOT / "contracts" / "architecture" / "authorities.yaml"
            ).read_text(encoding="utf-8")
        )
        room_states = [
            state for state in payload["states"]
            if str(state.get("id") or "").startswith("rooms.")
        ]
        self.assertGreaterEqual(len(room_states), 6)
        for state in room_states:
            with self.subTest(state=state["id"]):
                self.assertEqual(
                    "room-control-service",
                    state["current_deployable"],
                )

    def test_room_control_deployment_is_present_and_bounded(self):
        manifest = (
            ROOT / "deploy" / "kubernetes" / "base" / "room-control.yaml"
        ).read_text(encoding="utf-8")
        self.assertIn("name: funkey-room-control", manifest)
        self.assertIn("containerPort: 8085", manifest)
        self.assertIn("funkey-room-control-secrets", manifest)
        self.assertIn("readOnlyRootFilesystem: true", manifest)
        autoscaling = (
            ROOT / "deploy" / "kubernetes" / "base" / "autoscaling.yaml"
        ).read_text(encoding="utf-8")
        self.assertIn("name: funkey-room-control", autoscaling)
        self.assertIn("maxReplicas: 20", autoscaling)


if __name__ == "__main__":
    import unittest
    unittest.main()
