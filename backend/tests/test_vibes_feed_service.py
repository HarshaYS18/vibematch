from __future__ import annotations

from datetime import datetime
from pathlib import Path
import sys
from unittest import TestCase


BACKEND = Path(__file__).resolve().parents[1]
ROOT = BACKEND.parent
sys.path.insert(0, str(BACKEND))

from app.services.vibes_feed_service import (
    FeedCandidateProvider,
    FeedPolicy,
    FeedRanker,
    FeedRepository,
    decode_feed_cursor,
    encode_feed_cursor,
)


class VibesFeedServiceTests(TestCase):
    def test_cursor_round_trip_is_stable(self):
        created_at = datetime(2026, 9, 24, 8, 30, 15, 123456)
        cursor = encode_feed_cursor(created_at, 987)
        decoded = decode_feed_cursor(cursor)
        self.assertIsNotNone(decoded)
        self.assertEqual(created_at, decoded.created_at)
        self.assertEqual(987, decoded.post_id)

    def test_invalid_cursor_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Invalid Vibes feed cursor"):
            decode_feed_cursor("not-a-valid-cursor")

    def test_ranking_seam_is_explicit(self):
        repository = FeedRepository()
        self.assertIsInstance(repository.candidates, FeedCandidateProvider)
        self.assertIsInstance(repository.policy, FeedPolicy)
        self.assertIsInstance(repository.ranker, FeedRanker)

    def test_feed_serializer_has_no_per_post_query(self):
        source = (
            ROOT / "backend" / "app" / "api" / "routes" / "vibes.py"
        ).read_text(encoding="utf-8")
        start = source.index("def _post_response(")
        end = source.index("\n\ndef ", start)
        serializer = source[start:end]
        self.assertNotIn("func.count(", serializer)
        self.assertNotIn("db.query(", serializer)

    def test_service_and_counter_migration_are_present(self):
        self.assertTrue((ROOT / "apps" / "vibes-service" / "main.py").exists())
        migration = (
            ROOT / "backend" / "alembic" / "versions"
            / "20260924_0100_vibes_feed_service.py"
        ).read_text(encoding="utf-8")
        for counter in (
            "likes_count",
            "comments_count",
            "shares_count",
            "saves_count",
            "reports_count",
        ):
            self.assertIn(counter, migration)
