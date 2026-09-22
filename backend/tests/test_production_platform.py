import sys
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch
from uuid import uuid4

import fakeredis
from fastapi import HTTPException, Request
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.routes import auth, media_control, realtime_gateway_auth
from app.core.config import Settings, settings
from app.core.rate_limit import check_rate_limit
from app.database import Base
from app.models.event_outbox import WorkerProcessedEvent
from app.models.notification import UserNotification
from app.models.user import User
from app.services.identity_service import generate_public_user_id

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from apps.worker.events import EventEnvelope
from apps.worker import handlers


class ProductionConfigTests(TestCase):
    def test_production_rejects_defaults_and_excess_db_connections(self):
        with self.assertRaisesRegex(RuntimeError, "JWT_SECRET_KEY"):
            Settings(APP_ENV="production", _env_file=None).validate_production()
        safe = dict(
            APP_ENV="production", JWT_SECRET_KEY="j" * 40,
            MEDIA_INTERNAL_TOKEN="m" * 40, INBOX_BACKUP_ENCRYPTION_KEY="b" * 40,
            GOOGLE_AUTH_CLIENT_IDS="client.apps.googleusercontent.com",
            CORS_ALLOWED_ORIGINS="https://funkey.example",
            MEDIA_STORAGE_DRIVER="s3", MEDIA_S3_BUCKET="bucket",
            MEDIA_CDN_BASE_URL="https://cdn.funkey.example", RATE_LIMIT_ENABLED=True,
            database_url="postgresql://funkey:strong-secret@postgres.internal:5432/funkey",
            redis_url="rediss://cache.internal:6379/0",
        )
        Settings(**safe, _env_file=None).validate_production()
        with self.assertRaisesRegex(RuntimeError, "database_url\\(default\\)"):
            Settings(**{**safe, "database_url": "postgresql://postgres:postgres@localhost:5432/vibematch"}, _env_file=None).validate_production()
        with self.assertRaisesRegex(RuntimeError, "redis_url\\(default\\)"):
            Settings(**{**safe, "redis_url": "redis://localhost:6379/0"}, _env_file=None).validate_production()
        with self.assertRaisesRegex(RuntimeError, "DB_API_CONNECTION_BUDGET"):
            Settings(**safe, DB_POOL_SIZE=10, DB_API_CONNECTION_BUDGET=100, _env_file=None).validate_production()


class IdentityAllocationTests(TestCase):
    def test_non_postgres_public_ids_expand_capacity_and_keep_prefix(self):
        db_engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
        Base.metadata.create_all(db_engine, tables=[User.__table__])
        factory = sessionmaker(bind=db_engine)
        with factory() as db:
            public_id = generate_public_user_id(db)
        self.assertTrue(str(public_id).startswith("6418"))
        self.assertEqual(len(str(public_id)), 13)
        db_engine.dispose()


class GoogleAccessTokenTests(TestCase):
    def test_access_token_must_belong_to_an_allowed_google_client(self):
        tokeninfo = Mock(status_code=200)
        tokeninfo.json.return_value = {
            "audience": "other-client.apps.googleusercontent.com",
            "expires_in": 3600,
        }
        with patch.object(auth.settings, "GOOGLE_AUTH_CLIENT_IDS", "funkey-client.apps.googleusercontent.com"), \
             patch.object(auth.requests, "get", return_value=tokeninfo) as get:
            with self.assertRaises(HTTPException) as raised:
                auth._google_profile_from_access_token("google-token")
        self.assertEqual(raised.exception.status_code, 401)
        self.assertEqual(get.call_count, 1)


class DistributedRateLimitTests(TestCase):
    def test_shared_redis_limit_is_atomic_and_identity_is_hashed(self):
        redis = fakeredis.FakeRedis(decode_responses=True)
        first = check_rate_limit(redis, category="auth", identity="ip:192.0.2.1", limit=2, now=120)
        second = check_rate_limit(redis, category="auth", identity="ip:192.0.2.1", limit=2, now=120)
        third = check_rate_limit(redis, category="auth", identity="ip:192.0.2.1", limit=2, now=120)
        self.assertTrue(first[0])
        self.assertTrue(second[0])
        self.assertFalse(third[0])
        self.assertNotIn("192.0.2.1", next(iter(redis.scan_iter())))


class GatewayAuthTests(TestCase):
    def test_subscription_requires_authoritative_room_decision(self):
        room = SimpleNamespace(is_active=True)
        db = Mock()
        db.query.return_value.filter.return_value.first.return_value = room
        user = SimpleNamespace(id=7)
        with patch.object(realtime_gateway_auth, "decode_access_token", return_value={"device_id": "device"}), \
             patch.object(realtime_gateway_auth, "is_device_banned", return_value=False), \
             patch.object(realtime_gateway_auth, "evaluate_media_room_permission", return_value=SimpleNamespace(allowed=False, reason="kicked")):
            with self.assertRaises(HTTPException) as raised:
                realtime_gateway_auth.verify_realtime_gateway(
                    realtime_gateway_auth.RealtimeVerifyRequest(requested_action="subscribe", room_public_id="VM123"),
                    authorization="Bearer test", current_user=user, db=db,
                )
        self.assertEqual(raised.exception.status_code, 403)

    def test_internal_media_drain_uses_registry(self):
        redis = fakeredis.FakeRedis()
        from app.services.media_node_registry_service import heartbeat_node
        heartbeat_node(redis, node_id="node-1", public_url="https://media.example",
                       room_count=0, peer_count=0, max_rooms=10, max_peers=100, room_ids=[])
        request = Request({"type": "http", "headers": [(b"x-media-internal-token", settings.MEDIA_INTERNAL_TOKEN.encode())]})
        with patch.object(media_control, "get_redis", return_value=redis):
            drained = media_control.media_node_internal_drain("node-1", request)
        self.assertTrue(drained.draining)


class WorkerIdempotencyTests(TestCase):
    def test_notification_is_inserted_once_for_duplicate_delivery(self):
        db_engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
        Base.metadata.create_all(db_engine, tables=[User.__table__, UserNotification.__table__, WorkerProcessedEvent.__table__])
        factory = sessionmaker(bind=db_engine)
        with factory.begin() as db:
            db.add(User(id=7, public_user_id=6418000007, username="recipient"))
        event = EventEnvelope(
            event_id=uuid4(), event_type="notification.requested", event_version=1,
            occurred_at=datetime.now(timezone.utc),
            payload={"recipient_user_id": 7, "notification_type": "test", "title": "Hello", "body": "Body"},
        )
        with patch.object(handlers, "SessionLocal", factory):
            self.assertEqual(handlers.handle_notification_requested(event), "processed")
            self.assertEqual(handlers.handle_notification_requested(event), "duplicate")
        with factory() as db:
            self.assertEqual(db.query(UserNotification).count(), 1)
        db_engine.dispose()
