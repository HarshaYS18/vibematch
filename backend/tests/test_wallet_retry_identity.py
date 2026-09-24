from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class WalletRetryIdentityTests(unittest.TestCase):
    def test_flutter_wallet_mutations_reuse_pending_ids(self):
        source=(ROOT/"frontend/vibematch_app/lib/features/wallet/data/wallet_api_service.dart").read_text(encoding="utf-8")
        self.assertIn("wallet_recharge_pending_",source)
        self.assertIn("wallet_convert_pending_",source)
        self.assertIn("const Uuid().v4()",source)
        self.assertIn("'request_id': requestId",source)
        self.assertIn("'provider_reference': providerReference",source)

if __name__=="__main__":
    unittest.main()
