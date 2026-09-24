from __future__ import annotations

import os
import unittest

from sqlalchemy import create_engine, text


DATABASE_URL = os.getenv("MIGRATION_TEST_DATABASE_URL", "").strip()


def _index_names(plan: object) -> set[str]:
    found: set[str] = set()
    if isinstance(plan, dict):
        name = plan.get("Index Name")
        if isinstance(name, str):
            found.add(name)
        for value in plan.values():
            found.update(_index_names(value))
    elif isinstance(plan, list):
        for value in plan:
            found.update(_index_names(value))
    return found


@unittest.skipUnless(DATABASE_URL, "PostgreSQL plan test requires MIGRATION_TEST_DATABASE_URL")
class PostgresHotQueryPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = create_engine(DATABASE_URL)
        with cls.engine.begin() as db:
            db.execute(text("TRUNCATE TABLE vibe_saves, vibe_posts, inbox_messages, inbox_participants, inbox_conversations, users RESTART IDENTITY CASCADE"))
            db.execute(text("""
                INSERT INTO users (id, public_user_id, is_active, is_banned, is_protected, created_at, updated_at)
                VALUES
                  (1, 6418000000001, TRUE, FALSE, FALSE, NOW(), NOW()),
                  (2, 6418000000002, TRUE, FALSE, FALSE, NOW(), NOW())
            """))
            db.execute(text("""
                INSERT INTO vibe_posts (
                    author_user_id, caption, media_type, uses_mention_all,
                    comments_enabled, is_deleted, created_at, updated_at,
                    likes_count, comments_count, shares_count, saves_count, reports_count
                )
                SELECT
                    1,
                    'plan-test-' || g,
                    'text',
                    FALSE,
                    TRUE,
                    (g % 20 = 0),
                    NOW() - (g * INTERVAL '1 second'),
                    NOW(),
                    0, 0, 0, 0, 0
                FROM generate_series(1, 12000) AS g
            """))
            db.execute(text("""
                INSERT INTO vibe_saves (post_id, user_id, created_at)
                SELECT id, 2, created_at
                FROM vibe_posts
                WHERE id % 2 = 0
            """))
            db.execute(text("""
                INSERT INTO inbox_conversations (
                    public_id, title, avatar_text, conversation_type,
                    is_official, is_locked, is_blocked, is_muted,
                    is_pinned, is_archived, created_at, updated_at
                )
                VALUES (
                    'plan_conversation', 'Plan Test', 'PT', 'chat',
                    FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NOW(), NOW()
                )
            """))
            db.execute(text("""
                INSERT INTO inbox_participants (
                    conversation_id, user_id, unread_count,
                    is_deleted_for_user, is_muted, is_pinned, is_archived,
                    created_at, updated_at
                )
                VALUES
                  (1, 1, 0, FALSE, FALSE, FALSE, FALSE, NOW(), NOW()),
                  (1, 2, 0, FALSE, FALSE, FALSE, FALSE, NOW(), NOW())
            """))
            db.execute(text("""
                INSERT INTO inbox_messages (
                    public_id, conversation_id, sender_user_id, sender_name,
                    message_type, text, status, is_starred, is_forwarded,
                    created_at, updated_at
                )
                SELECT
                    'plan_message_' || g,
                    1,
                    CASE WHEN g % 2 = 0 THEN 1 ELSE 2 END,
                    'Plan User',
                    'text',
                    'message ' || g,
                    'sent',
                    FALSE,
                    FALSE,
                    NOW() - (g * INTERVAL '1 second'),
                    NOW()
                FROM generate_series(1, 12000) AS g
            """))
            db.execute(text("ANALYZE vibe_posts"))
            db.execute(text("ANALYZE vibe_saves"))
            db.execute(text("ANALYZE inbox_messages"))

    @classmethod
    def tearDownClass(cls):
        with cls.engine.begin() as db:
            db.execute(text("TRUNCATE TABLE vibe_saves, vibe_posts, inbox_messages, inbox_participants, inbox_conversations, users RESTART IDENTITY CASCADE"))
        cls.engine.dispose()

    def _explain(self, sql: str, params: dict | None = None) -> set[str]:
        with self.engine.connect() as db:
            payload = db.execute(
                text("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql),
                params or {},
            ).scalar_one()
        return _index_names(payload)

    def test_live_vibes_feed_uses_partial_cursor_index(self):
        indexes = self._explain("""
            SELECT id
            FROM vibe_posts
            WHERE is_deleted IS FALSE
            ORDER BY created_at DESC, id DESC
            LIMIT 31
        """)
        self.assertIn("ix_vibe_posts_live_feed_cursor", indexes)

    def test_saved_vibes_feed_uses_user_time_cursor_index(self):
        indexes = self._explain("""
            SELECT s.post_id
            FROM vibe_saves AS s
            JOIN vibe_posts AS p ON p.id = s.post_id
            WHERE s.user_id = :user_id
              AND p.is_deleted IS FALSE
            ORDER BY s.created_at DESC
            LIMIT 51
        """, {"user_id": 2})
        self.assertIn("ix_vibe_saves_user_created_post", indexes)

    def test_inbox_history_uses_conversation_cursor_index(self):
        indexes = self._explain("""
            SELECT id
            FROM inbox_messages
            WHERE conversation_id = :conversation_id
            ORDER BY created_at DESC, id DESC
            LIMIT 51
        """, {"conversation_id": 1})
        self.assertIn("ix_inbox_messages_conversation_cursor", indexes)


if __name__ == "__main__":
    unittest.main()
