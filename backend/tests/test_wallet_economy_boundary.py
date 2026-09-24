from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class WalletEconomyBoundaryTests(unittest.TestCase):
    def test_core_wallet_mutations_delegate_to_economy(self):
        source=(ROOT/"backend/app/api/routes/wallet/__init__.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.recharge_wallet",source)
        self.assertIn("economy_service_client.convert_ruby",source)
        self.assertIn("economy_service_client.withdraw_ruby",source)
        for forbidden in ("wallet.coin_balance +=", "WalletLedger("):
            # The route may still reference the model for read-only ledger output,
            # but it must not construct financial ledger mutations.
            self.assertNotIn(forbidden,source)

    def test_wallet_response_is_read_only(self):
        source=(ROOT/"backend/app/api/routes/wallet/__init__.py").read_text(encoding="utf-8")
        start=source.index("def _wallet_response")
        end=source.index("\ndef _response_json",start)
        block=source[start:end]
        self.assertNotIn("get_or_create_wallet(",block)
        self.assertNotIn("sync_vip_status(",block)

    def test_economy_profile_reads_do_not_create_wallet_or_sync_vip(self):
        route=(ROOT/"backend/app/api/routes/economy.py").read_text(encoding="utf-8")
        for function_name, next_marker in (
            ("def _public_wallet_summary", "\ndef _private_wallet_payload"),
            ("def _private_wallet_payload", "\ndef _active_room_user_ids"),
        ):
            start=route.index(function_name)
            end=route.index(next_marker,start)
            block=route[start:end]
            self.assertNotIn("get_or_create_wallet(",block)
            self.assertNotIn("sync_vip_status(",block)

        service=(ROOT/"backend/app/services/economy_service.py").read_text(encoding="utf-8")
        start=service.index("def dashboard_for_user")
        end=service.index("\n\ndef credit_social_mission_reward",start)
        dashboard=service[start:end]
        self.assertNotIn("get_or_create_wallet(",dashboard)
        self.assertNotIn(".commit(",dashboard)

    def test_wallet_routes_remain_core_for_realtime_facade(self):
        central=(ROOT/"backend/app/api/router.py").read_text(encoding="utf-8")
        main=(ROOT/"apps/economy-service/main.py").read_text(encoding="utf-8")
        proxy=(ROOT/"backend/app/api/routes/economy_proxy.py").read_text(encoding="utf-8")
        self.assertIn("wallet.router",central)
        self.assertNotIn("wallet.router",main)
        self.assertNotIn('"wallets"',proxy)

if __name__=="__main__":
    unittest.main()
