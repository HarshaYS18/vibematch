from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class EconomyLuckyGiftAdminCutoverTests(unittest.TestCase):
    def test_core_admin_mutations_delegate_to_economy(self):
        route = (ROOT / "backend/app/api/routes/lucky_gift_admin.py").read_text(encoding="utf-8")
        for token in (
            "economy_service_client.update_lucky_gift_props",
            "economy_service_client.adjust_lucky_gift_pool",
            "economy_service_client.allocate_lucky_gift_pool",
            "economy_service_client.withdraw_lucky_gift_pool",
            "economy_service_client.update_lucky_gift_pool_settings",
            "create_admin_log(",
        ):
            self.assertIn(token, route)
        for token in (
            "lucky_gift_props_service.update_props(",
            "lucky_gift_house_service.adjust_pool(",
            "lucky_gift_house_service.allocate_main_to_lucky(",
            "lucky_gift_house_service.withdraw_lucky_to_main(",
            "lucky_gift_house_service.update_pool_settings(",
        ):
            self.assertNotIn(token, route)

    def test_economy_internal_commands_are_idempotent_and_audited(self):
        internal = (ROOT / "apps/economy-service/internal.py").read_text(encoding="utf-8")
        for token in (
            '@router.post("/lucky-gifts/admin/props"',
            '@router.post("/lucky-gifts/admin/house-pool/adjust"',
            '@router.post("/lucky-gifts/admin/house-pool/allocate"',
            '@router.post("/lucky-gifts/admin/house-pool/withdraw"',
            '@router.post("/lucky-gifts/admin/house-pool/settings"',
            'operation="lucky_gift.props.update"',
            'operation="lucky_gift.pool.adjust"',
            'operation="lucky_gift.pool.allocate"',
            'operation="lucky_gift.pool.withdraw"',
            'operation="lucky_gift.pool.settings"',
            "economy.lucky_gift.props_updated.v1",
            "economy.lucky_gift.pool_adjusted.v1",
            "economy.lucky_gift.pool_allocated.v1",
            "economy.lucky_gift.pool_withdrawn.v1",
            "economy.lucky_gift.pool_settings_updated.v1",
        ):
            self.assertIn(token, internal)

    def test_legacy_helpers_support_outer_economy_transaction(self):
        props = (ROOT / "backend/app/services/lucky_gift_props_service.py").read_text(encoding="utf-8")
        house = (ROOT / "backend/app/services/lucky_gift_house_service.py").read_text(encoding="utf-8")
        self.assertIn("commit: bool = True", props)
        self.assertGreaterEqual(house.count("commit: bool = True"), 5)
        internal = (ROOT / "apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertGreaterEqual(internal.count("commit=False"), 5)

    def test_admin_requests_accept_retry_identity(self):
        schemas = (ROOT / "backend/app/schemas/lucky_gifts_admin.py").read_text(encoding="utf-8")
        self.assertGreaterEqual(schemas.count("request_id: str | None"), 3)
        route = (ROOT / "backend/app/api/routes/lucky_gift_admin.py").read_text(encoding="utf-8")
        self.assertIn('payload.get("request_id")', route)
        self.assertGreaterEqual(route.count("payload.request_id"), 4)


if __name__ == "__main__":
    unittest.main()
