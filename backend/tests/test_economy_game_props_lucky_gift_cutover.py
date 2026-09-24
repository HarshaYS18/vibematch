from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class EconomyGamePropsLuckyGiftCutoverTests(unittest.TestCase):
    def test_lucky_gift_game_props_facade_delegates_to_economy(self):
        route = (ROOT / "backend/app/api/routes/game_props_admin.py").read_text(encoding="utf-8")
        for token in (
            "economy_service_client.get_lucky_gift_admin_props",
            "economy_service_client.update_lucky_gift_props",
            "economy_service_client.get_lucky_gift_control_house_pool",
            "economy_service_client.update_lucky_gift_control_house_pool",
        ):
            self.assertIn(token, route)
        for token in (
            "GamePool",
            "EconomyPoolStatus",
            "house_pool_service",
            "lucky_gift_props_service",
            "_get_or_create_lucky_gift_house_pool",
        ):
            self.assertNotIn(token, route)

    def test_jungle_hunt_remains_on_existing_core_boundary(self):
        route = (ROOT / "backend/app/api/routes/game_props_admin.py").read_text(encoding="utf-8")
        self.assertIn("jungle_hunt_props_runtime_service.get_props", route)
        self.assertIn("jungle_hunt_props_runtime_service.update_props", route)

    def test_control_house_pool_command_is_idempotent_economy_work(self):
        internal = (ROOT / "apps/economy-service/internal.py").read_text(encoding="utf-8")
        for token in (
            '@router.get("/lucky-gifts/admin/control-center/house-pool"',
            '@router.post("/lucky-gifts/admin/control-center/house-pool"',
            'operation="lucky_gift.control_house_pool.update"',
            "economy.lucky_gift.control_house_pool_updated.v1",
        ):
            self.assertIn(token, internal)

    def test_house_pool_request_supports_retry_identity(self):
        schema = (ROOT / "backend/app/schemas/game_props.py").read_text(encoding="utf-8")
        self.assertIn("request_id: str | None", schema)
        route = (ROOT / "backend/app/api/routes/game_props_admin.py").read_text(encoding="utf-8")
        self.assertIn("payload.request_id", route)
        self.assertIn('payload.get("request_id")', route)


if __name__ == "__main__":
    unittest.main()
