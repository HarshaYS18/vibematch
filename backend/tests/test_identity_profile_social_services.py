import re
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class IdentityProfileSocialBoundaryTests(unittest.TestCase):
    def test_service_roots_exist(self):
        for relative in (
            "apps/identity-service/main.py",
            "apps/profile-social-service/main.py",
            "backend/app/api/routes/identity_proxy.py",
            "backend/app/api/routes/profile_social_proxy.py",
        ):
            self.assertTrue((ROOT / relative).exists(), relative)

    def test_new_tokens_are_session_backed(self):
        security = (ROOT / "backend/app/core/security.py").read_text(encoding="utf-8")
        auth = (ROOT / "backend/app/api/routes/auth.py").read_text(encoding="utf-8")
        users = (ROOT / "backend/app/api/routes/users.py").read_text(encoding="utf-8")
        self.assertIn('payload["sid"] = session_id', security)
        self.assertIn("identity_session_service.open_session", auth)
        self.assertIn("identity_service_client.verify_access_token", users)
        self.assertNotIn("identity_session_service.is_session_active", users)

    def test_core_uses_extracted_route_proxies(self):
        router = (ROOT / "backend/app/api/router.py").read_text(encoding="utf-8")
        self.assertIn("identity_proxy.router", router)
        self.assertIn("profile_social_proxy.router", router)
        for forbidden in (
            "auth.router",
            "admin.router",
            "moderation.router",
            "social.router",
            "love_bonds.router",
            "families.router",
            "profile_display.router",
        ):
            self.assertIsNone(
                re.search(
                    rf"(?<![A-Za-z0-9_]){re.escape(forbidden)}\\b",
                    router,
                ),
                forbidden,
            )

    def test_identity_owns_privileged_account_security_routes(self):
        identity = (ROOT / "apps/identity-service/main.py").read_text(encoding="utf-8")
        self.assertIn("api.include_router(admin.router)", identity)
        self.assertIn("api.include_router(moderation.router)", identity)
        permissions = (ROOT / "backend/app/services/special_permission_service.py").read_text(encoding="utf-8")
        self.assertIn("Authorization reads are side-effect free", permissions)

    def test_super_owner_profile_commands_delegate_to_profile_social(self):
        source = (ROOT / "backend/app/api/routes/super_owner.py").read_text(encoding="utf-8")
        self.assertNotIn("target.display_custom_id =", source)
        self.assertNotIn("target.interests =", source)
        self.assertIn("profile_social_service_client.assign_custom_id", source)
        self.assertIn("profile_social_service_client.set_stealth", source)

    def test_profile_mutation_routes_to_service(self):
        users = (ROOT / "backend/app/api/routes/users.py").read_text(encoding="utf-8")
        internal = (ROOT / "apps/profile-social-service/internal.py").read_text(encoding="utf-8")
        profile = (ROOT / "backend/app/services/profile_service.py").read_text(encoding="utf-8")
        self.assertIn("profile_social_service_client.update_profile", users)
        self.assertIn("db.refresh(current_user)", users)
        self.assertNotIn("return users._user_me_response", internal)
        wallet_start = profile.index("def wallet_summary")
        wallet_end = profile.find("\ndef ", wallet_start + 5)
        wallet_source = profile[wallet_start:] if wallet_end < 0 else profile[wallet_start:wallet_end]
        self.assertNotIn("get_or_create_wallet(", wallet_source)
        self.assertNotIn("sync_vip_status(", wallet_source)

    def test_reader_roles_preserve_read_without_mutation_authority(self):
        identity_sql = (ROOT / "deploy/postgres/identity-ownership.sql").read_text(encoding="utf-8")
        social_sql = (ROOT / "deploy/postgres/profile-social-ownership.sql").read_text(encoding="utf-8")
        self.assertIn("funkey_identity_reader", identity_sql)
        self.assertIn("funkey_profile_social_reader", social_sql)
        self.assertIn("GRANT SELECT ON TABLE users,user_roles,special_permissions,user_bans,device_bans TO funkey_identity_reader", identity_sql)
        self.assertIn("TO funkey_profile_social_reader", social_sql)

    def test_authority_registry_cutover(self):
        payload = json.loads(
            (ROOT / "contracts/architecture/authorities.yaml").read_text(encoding="utf-8")
        )
        states = {item["id"]: item for item in payload["states"]}
        self.assertEqual("identity-service", states["identity.accounts"]["current_deployable"])
        self.assertEqual("identity-service", states["identity.sessions"]["current_deployable"])
        self.assertEqual("profile-social-service", states["profiles.public"]["current_deployable"])
        self.assertEqual("profile-social-service", states["social.graph"]["current_deployable"])
        self.assertEqual("profile-social-service", states["families.membership"]["current_deployable"])


if __name__ == "__main__":
    unittest.main()
