from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomyPublicRouteExtractionTests(unittest.TestCase):
    def test_economy_service_mounts_unambiguous_financial_routes(self):
        main=(ROOT/"apps/economy-service/main.py").read_text(encoding="utf-8")
        for token in (
            "coin_sales.router",
            "lucky_coins.router",
            "lucky_packets.router",
            "gift_catalog.router",
            "lucky_gifts.router",
            "game_pool_admin.router",
            "coin_sales.admin_router",
            "gift_catalog.admin_router",
        ):
            self.assertIn(token,main)

    def test_core_uses_economy_proxy_for_extracted_route_families(self):
        central=(ROOT/"backend/app/api/router.py").read_text(encoding="utf-8")
        proxy=(ROOT/"backend/app/api/routes/economy_proxy.py").read_text(encoding="utf-8")
        self.assertIn("economy_proxy.router",central)
        for forbidden in (
            "coin_sales.router",
            "lucky_coins.router",
            "lucky_packets.router",
            "gift_catalog.router",
            "lucky_gifts.router",
            "game_pool_admin.router",
            "coin_sales.admin_router",
            "gift_catalog.admin_router",
        ):
            self.assertNotIn(forbidden,central)
        for prefix in (
            "coin-sales",
            "economy/lucky-coins",
            "lucky-packets",
            "gifts",
            "lucky-gifts",
            "admin/games/pools",
        ):
            self.assertIn(prefix,proxy)

if __name__=="__main__":
    unittest.main()
