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

    def test_super_owner_levels_delegate_to_economy(self):
        route=(ROOT/"backend/app/api/routes/super_owner.py").read_text(encoding="utf-8")
        start=route.index('@router.post("/admin/users/levels-adjust"')
        end=route.index('\n\n@router.get("/admin/moderation/owner-logs"',start)
        block=route[start:end]
        self.assertIn("economy_service_client.adjust_wallet_levels",block)
        self.assertIn("payload.request_id or str(uuid4())",block)
        self.assertNotIn("get_or_create_wallet(",block)
        self.assertNotIn("wallet.ruby_balance =",block)
        self.assertNotIn("wallet.lifetime_",block)

        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        start=internal.index("def admin_adjust_wallet_levels(")
        end=internal.index('\n\n@router.post("/wallet/recharge"',start)
        handler=internal[start:end]
        self.assertIn("wallet_for_update(",handler)
        self.assertIn("economy_transaction_service.credit(",handler)
        self.assertIn("economy_transaction_service.debit(",handler)
        self.assertIn("economy_transaction_service.complete(",handler)

    def test_control_center_persists_mint_retry_identity(self):
        source=(ROOT/"frontend/vibematch_app/lib/features/control_center/data/control_center_api_service.dart").read_text(encoding="utf-8")
        self.assertIn("_pendingMutationIdentity",source)
        self.assertIn("super_owner_mint",source)
        self.assertIn("body['request_id'] = pending.id",source)
        self.assertIn("SharedPreferences.getInstance()",source)
        self.assertIn("const Uuid().v4()",source)

if __name__=="__main__":
    unittest.main()
