from pathlib import Path
from unittest import TestCase


ROOT = Path(__file__).resolve().parents[2]


class RankingsReadOnlyProjectionTests(TestCase):
    def test_rankings_never_call_write_capable_projection_services(self):
        source = (
            ROOT / "backend/app/api/routes/rankings.py"
        ).read_text(encoding="utf-8")
        self.assertNotIn("get_or_create_user_exp", source)
        self.assertNotIn("profile_service.vip_summary", source)
        self.assertNotIn("experience_service", source)
        self.assertNotIn("db.add(", source)
        self.assertNotIn("db.commit(", source)
        self.assertNotIn("db.flush(", source)

    def test_rankings_batch_experience_and_vip_projection(self):
        source = (
            ROOT / "backend/app/api/routes/rankings.py"
        ).read_text(encoding="utf-8")
        self.assertIn("UserExperienceStatus.user_id.in_(resolved_ids)", source)
        self.assertIn("UserVipStatus.user_id.in_(resolved_ids)", source)
        self.assertIn("def _ranking_projection(", source)

    def test_recharge_ranking_uses_full_official_recharge_sources(self):
        source = (
            ROOT / "backend/app/api/routes/rankings.py"
        ).read_text(encoding="utf-8")
        for source_type in (
            "RECHARGE",
            "OFFICIAL_RECHARGE",
            "SELLER_COIN_SALE",
            "MERCHANT_COIN_SALE",
            "OWNER_RECHARGE",
            "FOUNDER_RECHARGE",
            "ROLE_COIN_SALE",
        ):
            self.assertIn(source_type, source)


if __name__ == "__main__":
    import unittest
    unittest.main()
