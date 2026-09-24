from __future__ import annotations

from pathlib import Path
from unittest import TestCase

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # register relationship targets
from app.core.operational import (
    begin_query_count,
    current_query_count,
    end_query_count,
    install_query_counter,
)
from app.core.query_budget import ROUTE_QUERY_BUDGETS, query_budget_for
from app.database import Base
from app.models.follow import UserFollow
from app.models.user import User
from app.models.vibe import VibePost, VibeReaction, VibeSave
from app.services.vibes_feed_service import FeedRepository


ROOT = Path(__file__).resolve().parents[2]


class QueryBudgetContractTests(TestCase):
    def test_hot_reads_have_explicit_small_query_budgets(self):
        expected = {
            ("GET", "/api/v1/vibes/feed"): 6,
            ("GET", "/api/v1/vibes/friends"): 6,
            ("GET", "/api/v1/vibes/saved"): 6,
            ("GET", "/api/v1/inbox/conversations"): 8,
            ("GET", "/api/v1/inbox/conversations/{conversation_id}/messages"): 8,
        }
        for key, ceiling in expected.items():
            with self.subTest(route=key):
                self.assertEqual(ceiling, ROUTE_QUERY_BUDGETS[key])
                self.assertEqual(ceiling, query_budget_for(*key))

    def test_vibes_feed_query_count_is_page_size_independent(self):
        engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(
            engine,
            tables=[
                User.__table__,
                UserFollow.__table__,
                VibePost.__table__,
                VibeReaction.__table__,
                VibeSave.__table__,
            ],
        )
        install_query_counter(engine)
        factory = sessionmaker(bind=engine)
        with factory.begin() as db:
            db.add_all([
                User(id=1, public_user_id=6418000000001, username="author"),
                User(id=2, public_user_id=6418000000002, username="viewer"),
            ])
            db.add_all([
                VibePost(
                    id=index,
                    author_user_id=1,
                    caption=f"post {index}",
                    media_type="text",
                )
                for index in range(1, 41)
            ])
            db.add_all([
                VibeReaction(post_id=index, user_id=2, reaction_type="like")
                for index in range(1, 10)
            ])
            db.add_all([
                VibeSave(post_id=index, user_id=2)
                for index in range(10, 20)
            ])

        with factory() as db:
            viewer = db.get(User, 2)
            token = begin_query_count()
            try:
                page = FeedRepository().page(
                    db,
                    current_user=viewer,
                    mode="global",
                    limit=30,
                )
                count = current_query_count()
            finally:
                end_query_count(token)

        self.assertEqual(30, len(page.posts))
        self.assertLessEqual(
            count,
            query_budget_for("GET", "/api/v1/vibes/feed"),
        )
        self.assertLessEqual(count, 3)
        engine.dispose()

    def test_inbox_list_uses_page_batched_message_windows(self):
        route = (
            ROOT / "backend" / "app" / "api" / "routes" / "inbox.py"
        ).read_text(encoding="utf-8")
        service = (
            ROOT / "backend" / "app" / "services" / "inbox_service.py"
        ).read_text(encoding="utf-8")
        self.assertIn("conversation_message_windows(", route)
        self.assertIn("func.row_number().over(", service)
        self.assertIn("selectinload(InboxConversation.participants)", service)

    def test_extracted_services_install_query_counting_and_metrics(self):
        for relative in (
            "apps/inbox-service/main.py",
            "apps/vibes-service/main.py",
        ):
            source = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIn('app.middleware("http")(operational_middleware)', source)
            self.assertIn("install_query_counter(engine)", source)
            self.assertIn('app.get("/metrics"', source)

    def test_storage_policy_forbids_speculative_replica_and_partitioning(self):
        policy = (
            ROOT / "contracts" / "database" / "storage-policy.json"
        ).read_text(encoding="utf-8")
        self.assertIn('"enabled": false', policy)
        self.assertIn('"approved_stale_tolerant_routes": []', policy)
        self.assertIn('"enabled_tables": []', policy)
        self.assertIn('"durable_authority": false', policy)


if __name__ == "__main__":
    unittest.main()
