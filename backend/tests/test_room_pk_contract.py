from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RoomPkContractTests(unittest.TestCase):
    def test_room_control_exposes_authoritative_pk_routes(self):
        route = (
            ROOT / "backend/app/api/routes/rooms/pk.py"
        ).read_text(encoding="utf-8")
        for marker in (
            '"/candidates"',
            '"/current"',
            '"/challenge"',
            '"/{match_public_id}/decision"',
            '"/{match_public_id}/cancel"',
            '"/{match_public_id}/finish"',
            '"room_pk/state"',
        ):
            self.assertIn(marker, route)

    def test_pk_winner_is_calculated_on_backend(self):
        service = (
            ROOT / "backend/app/services/rooms/room_pk_service.py"
        ).read_text(encoding="utf-8")
        self.assertIn("match.challenger_score", service)
        self.assertIn("match.opponent_score", service)
        self.assertIn("match.winner_room_id", service)
        self.assertIn("RoomPkScoreReceipt(", service)
        self.assertIn("source_event_id", service)
        self.assertIn("_reconcile_scores_from_economy", service)
        self.assertIn("GiftTransaction.total_coin_value", service)

    def test_economy_scores_pk_only_after_settlement_path(self):
        route = (
            ROOT / "backend/app/api/routes/economy.py"
        ).read_text(encoding="utf-8")
        settle = route.index("economy_service_client.settle_gift(")
        commit = route.index("db.commit()", settle)
        scoring = route.index("_queue_room_gift_event(", commit)
        self.assertLess(settle, commit)
        self.assertLess(commit, scoring)
        self.assertIn("room_control_service_client.apply_pk_gift_score", route)

    def test_pk_tables_are_room_control_owned(self):
        ownership = (
            ROOT / "deploy/postgres/room-control-ownership.sql"
        ).read_text(encoding="utf-8")
        self.assertIn("room_pk_matches", ownership)
        self.assertIn("room_pk_score_receipts", ownership)


if __name__ == "__main__":
    unittest.main()
