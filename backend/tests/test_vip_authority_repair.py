from pathlib import Path
from unittest import TestCase


ROOT = Path(__file__).resolve().parents[2]


class VipAuthorityRepairTests(TestCase):
    def test_public_admin_routes_do_not_write_vip_projection(self):
        for relative in (
            "backend/app/api/routes/super_owner.py",
            "backend/app/services/vip_status_service.py",
        ):
            source = (ROOT / relative).read_text(encoding="utf-8")
            self.assertNotIn("db.query(UserVipStatus)", source if "super_owner" in relative else source.replace("db.query(UserVipStatus)", "READ_ONLY_QUERY", 1))
            self.assertNotIn("status.vip_level =", source)
            self.assertNotIn("status.svip_level =", source)

    def test_super_owner_uses_economy_override_command(self):
        source = (
            ROOT / "backend/app/api/routes/super_owner.py"
        ).read_text(encoding="utf-8")
        self.assertIn("economy_service_client.adjust_vip_override", source)
        self.assertNotIn("UserVipStatus(", source)

    def test_vip_projection_honors_manual_override_and_emits_event(self):
        source = (
            ROOT / "backend/app/services/economy_level_service.py"
        ).read_text(encoding="utf-8")
        self.assertIn("UserVipOverride", source)
        self.assertIn("set_vip_override", source)
        self.assertIn("economy.vip_projection.updated.v1", source)

    def test_economy_owns_vip_projection_tables(self):
        ownership = (
            ROOT / "deploy/postgres/economy-ownership.sql"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "ALTER TABLE user_vip_statuses OWNER TO funkey_economy_owner",
            ownership,
        )
        self.assertIn(
            "ALTER TABLE user_vip_overrides OWNER TO funkey_economy_owner",
            ownership,
        )


if __name__ == "__main__":
    import unittest
    unittest.main()
