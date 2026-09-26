from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class IdentityProfileSocialControlCenterBoundaryTests(unittest.TestCase):
    def test_control_center_no_longer_writes_identity_or_profile_social_tables(self):
        source = (ROOT / "backend/app/api/routes/control_center.py").read_text(encoding="utf-8")
        for token in (
            "identity_service_client.set_special_permission",
            "profile_social_service_client.get_stealth",
            "profile_social_service_client.set_stealth(",
            "profile_social_service_client.set_stealth_grant_state",
        ):
            self.assertIn(token, source)
        for token in (
            "SpecialPermission",
            "grant_special_permission(",
            "profile_display_service.get_or_create_stealth_state",
            "state.is_enabled =",
        ):
            self.assertNotIn(token, source)

    def test_identity_owns_special_permission_mutation_and_emits_event(self):
        source = (ROOT / "apps/identity-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/special-permissions/set"', source)
        self.assertIn("special_permission_service.grant_special_permission", source)
        self.assertIn("special_permission_service.revoke_special_permission", source)
        self.assertIn("identity.special_permission.changed.v1", source)

    def test_profile_social_owns_stealth_state_mutations_and_events(self):
        source = (ROOT / "apps/profile-social-service/internal.py").read_text(encoding="utf-8")
        for token in (
            '@router.get("/users/{user_id}/stealth"',
            '@router.post("/admin/users/{user_id}/stealth"',
            '@router.post("/admin/users/{user_id}/stealth-grant-state"',
            "profile_social.stealth.toggled.v1",
            "profile_social.stealth_eligibility.changed.v1",
        ):
            self.assertIn(token, source)

    def test_identity_runtime_can_write_domain_outbox(self):
        sql = (ROOT / "deploy/postgres/identity-ownership.sql").read_text(encoding="utf-8")
        self.assertIn("GRANT INSERT ON TABLE event_outbox TO funkey_identity_runtime", sql)


if __name__ == "__main__":
    unittest.main()
