from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class SuperOwnerMintEconomyCutoverTests(unittest.TestCase):
    def test_super_owner_mint_delegates_to_economy(self):
        route=(ROOT/"backend/app/api/routes/super_owner.py").read_text(encoding="utf-8")
        start=route.index('@router.post("/admin/economy/coins/mint"')
        end=route.index('\n\n@router.post("/admin/economy/coins/send-all"',start)
        block=route[start:end]
        self.assertIn("economy_service_client.mint_supply",block)
        self.assertNotIn("mint_to_pool(",block)
        self.assertIn("require_super_owner(current_user)",block)

    def test_control_center_persists_mint_retry_identity(self):
        source=(ROOT/"frontend/vibematch_app/lib/features/control_center/data/control_center_api_service.dart").read_text(encoding="utf-8")
        self.assertIn("_pendingMutationIdentity",source)
        self.assertIn("super_owner_mint",source)
        self.assertIn("body['request_id'] = pending.id",source)
        self.assertIn("SharedPreferences.getInstance()",source)
        self.assertIn("const Uuid().v4()",source)

if __name__=="__main__":
    unittest.main()
