from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]


class SuperOwnerSendAllBulkJobTests(unittest.TestCase):
    def test_super_owner_route_only_enqueues_bulk_job(self):
        source=(ROOT/"backend/app/api/routes/super_owner.py").read_text(encoding="utf-8")
        start=source.index("def send_coins_to_all(")
        end=source.index("\n\n@router.post(",start)
        block=source[start:end]
        self.assertIn("economy_service_client.queue_bulk_grant",block)
        self.assertNotIn("query.all()",block)
        self.assertNotIn("WalletLedger(",block)
        self.assertNotIn("wallet.coin_balance +=",block)
        self.assertIn("SUPER_OWNER_COINS_SEND_ALL_QUEUED",block)

    def test_request_schema_accepts_retry_identity(self):
        source=(ROOT/"backend/app/schemas/super_owner.py").read_text(encoding="utf-8")
        start=source.index("class SuperOwnerSendCoinsAllRequest")
        end=source.index("\nclass ",start+6)
        block=source[start:end]
        self.assertIn("request_id: str | None",block)

    def test_flutter_reuses_pending_send_all_identity(self):
        source=(
            ROOT
            / "frontend/vibematch_app/lib/features/control_center/data/control_center_api_service.dart"
        ).read_text(encoding="utf-8")
        self.assertIn("super_owner_send_all",source)
        self.assertIn("body['request_id'] = pending.id",source)
        self.assertIn("_clearPendingMutation(pending.key)",source)


if __name__=="__main__":
    unittest.main()
