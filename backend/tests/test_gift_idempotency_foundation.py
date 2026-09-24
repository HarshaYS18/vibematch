from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class GiftIdempotencyFoundationTests(unittest.TestCase):
    def test_exp_projection_has_durable_receipt(self):
        model=(ROOT/"backend/app/models/experience.py").read_text(encoding="utf-8")
        service=(ROOT/"backend/app/services/experience_service.py").read_text(encoding="utf-8")
        self.assertIn("class ExperienceMutationReceipt",model)
        self.assertIn("GIFT_SETTLEMENT:",service)
        self.assertIn("get_or_create_unique_with_created",service)
        self.assertIn('"duplicate": True',service)

    def test_public_gift_contract_accepts_request_id(self):
        schema=(ROOT/"backend/app/schemas/economy.py").read_text(encoding="utf-8")
        dart=(ROOT/"frontend/vibematch_app/lib/features/rooms/data/gift_api_service.dart").read_text(encoding="utf-8")
        self.assertIn("request_id: str | None",schema)
        self.assertIn("'request_id': requestId",dart)
        self.assertIn("gift_send_pending",dart)
        self.assertIn("const Uuid().v4()",dart)

if __name__=="__main__":
    unittest.main()
