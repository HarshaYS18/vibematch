from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomyOfficialRechargeCutoverTests(unittest.TestCase):
    def test_core_official_recharge_delegates_and_keeps_realtime(self):
        route=(ROOT/"backend/app/api/routes/economy_admin.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.official_recharge",route)
        self.assertIn("_broadcast_wallet_vip_svip_update",route)
        self.assertNotIn("credit_official_recharge(",route)
        self.assertNotIn("def _wallet_response(",route)
        self.assertNotIn("sync_vip_status(",route)

    def test_economy_recharge_is_idempotent_and_audited(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn('@router.post("/recharge/official"',internal)
        self.assertIn('operation="recharge.official"',internal)
        self.assertIn('source_type="OFFICIAL_RECHARGE"',internal)
        self.assertIn("metadata_json=json.dumps",internal)
        self.assertIn("economy.official_recharge.completed.v1",internal)

    def test_transaction_credit_can_preserve_metadata(self):
        source=(ROOT/"backend/app/services/economy_transaction_service.py").read_text(encoding="utf-8")
        self.assertIn("metadata_json:str|None=None",source)
        self.assertIn("metadata_json=metadata_json",source)

if __name__=="__main__":
    unittest.main()
