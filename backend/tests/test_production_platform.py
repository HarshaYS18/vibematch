import sys
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import Mock, patch
from uuid import uuid4

import fakeredis
from fastapi import HTTPException, Request
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.routes import auth, media_control, realtime_gateway_auth
from app.core.config import Settings, settings
from app.core.rate_limit import check_rate_limit, check_rate_limit_async
from app.database import Base
from app.models.event_outbox import EventOutbox, WorkerProcessedEvent
from app.models.notification import UserNotification
from app.models.user import User
from app.services.identity_service import generate_public_user_id
from app.services import outbox_relay_service

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from apps.worker.events import EventEnvelope
from apps.worker import handlers


class ProductionConfigTests(TestCase):
    def test_production_rejects_defaults_and_excess_db_connections(self):
        with self.assertRaisesRegex(RuntimeError, "JWT_SECRET_KEY"):
            Settings(APP_ENV="production", _env_file=None).validate_production()
        safe = dict(
            APP_ENV="production", JWT_SECRET_KEY="j" * 40,
            MEDIA_INTERNAL_TOKEN="m" * 40, INBOX_INTERNAL_TOKEN="i" * 40,
            VIBES_INTERNAL_TOKEN="v" * 40, ROOM_CONTROL_INTERNAL_TOKEN="r" * 40,
            IDENTITY_INTERNAL_TOKEN="d" * 40, PROFILE_SOCIAL_INTERNAL_TOKEN="p" * 40,
            ECONOMY_INTERNAL_TOKEN="e" * 40,
            INBOX_BACKUP_ENCRYPTION_KEY="b" * 40,
            GOOGLE_AUTH_CLIENT_IDS="client.apps.googleusercontent.com",
            REALTIME_CAPABILITY_PRIVATE_KEY_B64="AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
            CORS_ALLOWED_ORIGINS="https://funkey.example",
            MEDIA_STORAGE_DRIVER="s3", MEDIA_S3_BUCKET="bucket",
            MEDIA_CDN_BASE_URL="https://cdn.funkey.example", RATE_LIMIT_ENABLED=True,
            database_url="postgresql://funkey:strong-secret@postgres.internal:5432/funkey",
            redis_url="rediss://cache.internal:6379/0",
            CACHE_REDIS_URL="rediss://cache.internal:6379/0",
            REALTIME_REDIS_URL="rediss://realtime.internal:6379/0",
            MEDIA_REGISTRY_REDIS_URL="rediss://media-redis.internal:6379/0",
        )
        Settings(**safe, _env_file=None).validate_production()
        with self.assertRaisesRegex(RuntimeError, "database_url\\(default\\)"):
            Settings(**{**safe, "database_url": "postgresql://postgres:postgres@localhost:5432/vibematch"}, _env_file=None).validate_production()
        with self.assertRaisesRegex(RuntimeError, "CACHE_REDIS_URL"):
            Settings(**{**safe, "CACHE_REDIS_URL": ""}, _env_file=None).validate_production()
        with self.assertRaisesRegex(RuntimeError, "Redis role endpoint separation"):
            Settings(
                **{**safe, "REALTIME_REDIS_URL": safe["CACHE_REDIS_URL"]},
                _env_file=None,
            ).validate_production()
        with self.assertRaisesRegex(RuntimeError, "DB_API_CONNECTION_BUDGET"):
            Settings(**safe, DB_POOL_SIZE=10, DB_API_CONNECTION_BUDGET=100, _env_file=None).validate_production()
        with self.assertRaisesRegex(RuntimeError, "READ_REPLICA_DATABASE_URL"):
            Settings(
                **safe,
                DB_READ_REPLICA_ENABLED=True,
                READ_REPLICA_DATABASE_URL="",
                _env_file=None,
            ).validate_production()
        with self.assertRaisesRegex(RuntimeError, "READ_REPLICA_DATABASE_URL"):
            Settings(
                **safe,
                DB_READ_REPLICA_ENABLED=True,
                READ_REPLICA_DATABASE_URL=safe["database_url"],
                _env_file=None,
            ).validate_production()

    def test_transaction_pooling_requires_direct_migration_url_and_bounded_topology(self):
        safe = dict(
            APP_ENV="production", JWT_SECRET_KEY="j" * 40,
            MEDIA_INTERNAL_TOKEN="m" * 40, INBOX_INTERNAL_TOKEN="i" * 40,
            VIBES_INTERNAL_TOKEN="v" * 40, ROOM_CONTROL_INTERNAL_TOKEN="r" * 40,
            IDENTITY_INTERNAL_TOKEN="d" * 40, PROFILE_SOCIAL_INTERNAL_TOKEN="p" * 40,
            ECONOMY_INTERNAL_TOKEN="e" * 40,
            INBOX_BACKUP_ENCRYPTION_KEY="b" * 40,
            GOOGLE_AUTH_CLIENT_IDS="client.apps.googleusercontent.com",
            REALTIME_CAPABILITY_PRIVATE_KEY_B64="AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
            CORS_ALLOWED_ORIGINS="https://funkey.example",
            MEDIA_STORAGE_DRIVER="s3", MEDIA_S3_BUCKET="bucket",
            MEDIA_CDN_BASE_URL="https://cdn.funkey.example", RATE_LIMIT_ENABLED=True,
            database_url="postgresql://funkey:strong-secret@pgbouncer.internal:6432/funkey",
            MIGRATION_DATABASE_URL="postgresql://funkey_migrate:strong-secret@postgres.internal:5432/funkey",
            DB_POOLER_MODE="transaction",
            redis_url="rediss://cache.internal:6379/0",
            CACHE_REDIS_URL="rediss://cache.internal:6379/0",
            REALTIME_REDIS_URL="rediss://realtime.internal:6379/0",
            MEDIA_REGISTRY_REDIS_URL="rediss://media-redis.internal:6379/0",
        )
        settings_obj = Settings(**safe, _env_file=None)
        settings_obj.validate_production()
        self.assertEqual(
            "postgresql://funkey_migrate:strong-secret@postgres.internal:5432/funkey",
            settings_obj.migration_database_url,
        )
        self.assertEqual(668, settings_obj.expected_pooler_client_connections)

        with self.assertRaisesRegex(RuntimeError, "MIGRATION_DATABASE_URL"):
            Settings(
                **{**safe, "MIGRATION_DATABASE_URL": safe["database_url"]},
                _env_file=None,
            ).validate_production()
        with self.assertRaisesRegex(RuntimeError, "DB_POOLER_MAX_CLIENT_CONNECTIONS"):
            Settings(
                **safe,
                DB_POOLER_MAX_CLIENT_CONNECTIONS=100,
                _env_file=None,
            ).validate_production()
        with self.assertRaisesRegex(RuntimeError, "DB_SERVER_CONNECTION_LIMIT"):
            Settings(
                **safe,
                DB_POOLER_MAX_SERVER_CONNECTIONS=140,
                DB_DIRECT_CONNECTION_RESERVE=40,
                DB_SERVER_CONNECTION_LIMIT=160,
                _env_file=None,
            ).validate_production()


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


class AsyncDistributedRateLimitTests(IsolatedAsyncioTestCase):
    async def test_async_limit_uses_same_distributed_semantics(self):
        import fakeredis.aioredis

        redis = fakeredis.aioredis.FakeRedis(decode_responses=True)
        try:
            first = await check_rate_limit_async(redis, category="read", identity="user:7", limit=1, now=120)
            second = await check_rate_limit_async(redis, category="read", identity="user:7", limit=1, now=120)
            self.assertTrue(first[0])
            self.assertFalse(second[0])
        finally:
            await redis.aclose()


class GatewayAuthTests(TestCase):
    def test_subscription_requires_authoritative_room_decision(self):
        room = SimpleNamespace(is_active=True)
        db = Mock()
        db.query.return_value.filter.return_value.first.return_value = room
        user = SimpleNamespace(id=7)
        with patch.object(realtime_gateway_auth, "decode_access_token", return_value={"device_id": "device"}), \
             patch.object(realtime_gateway_auth, "is_device_banned", return_value=False), \
             patch.object(
                 realtime_gateway_auth.room_control_service_client,
                 "authorize_room_action",
                 return_value={"allowed": False, "reason": "kicked", "permissions": []},
             ):
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
        with patch.object(media_control, "get_media_registry_redis", return_value=redis):
            drained = media_control.media_node_internal_drain("node-1", request)
        self.assertTrue(drained.draining)


class OutboxLeaseTests(TestCase):
    def setUp(self):
        self.db_engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.db_engine, tables=[EventOutbox.__table__])
        self.factory = sessionmaker(bind=self.db_engine)
        self.now = datetime(2026, 9, 22, 12, 0, tzinfo=timezone.utc)
        with self.factory.begin() as db:
            db.add(EventOutbox(
                event_id=str(uuid4()),
                event_type="notification.requested",
                event_version=1,
                occurred_at=self.now,
                payload={"recipient_user_id": 7},
                attempt_count=0,
            ))

    def tearDown(self):
        self.db_engine.dispose()

    def test_claim_is_short_lived_exclusive_and_retryable(self):
        with patch.object(outbox_relay_service, "SessionLocal", self.factory):
            first = outbox_relay_service.claim_outbox_batch(
                "worker-a", now=self.now, lease_seconds=120
            )
            self.assertEqual(len(first), 1)
            self.assertEqual(first[0].attempt_count, 1)

            blocked = outbox_relay_service.claim_outbox_batch(
                "worker-b", now=self.now, lease_seconds=120
            )
            self.assertEqual(blocked, [])

            self.assertTrue(outbox_relay_service.release_outbox_claim(
                first[0].event_id,
                "worker-a",
                error="NatsTimeoutError",
                delay_seconds=60,
                now=self.now,
            ))
            too_early = outbox_relay_service.claim_outbox_batch(
                "worker-b",
                now=self.now.replace(minute=0, second=30),
                lease_seconds=120,
            )
            self.assertEqual(too_early, [])

            retry_at = self.now.replace(minute=1, second=1)
            retried = outbox_relay_service.claim_outbox_batch(
                "worker-b", now=retry_at, lease_seconds=120
            )
            self.assertEqual(len(retried), 1)
            self.assertEqual(retried[0].attempt_count, 2)
            self.assertTrue(outbox_relay_service.mark_outbox_published(
                retried[0].event_id,
                "worker-b",
                now=retry_at,
            ))
            self.assertEqual(
                outbox_relay_service.claim_outbox_batch(
                    "worker-c",
                    now=retry_at,
                    lease_seconds=120,
                ),
                [],
            )

    def test_expired_lease_can_be_reclaimed_after_worker_crash(self):
        with patch.object(outbox_relay_service, "SessionLocal", self.factory):
            first = outbox_relay_service.claim_outbox_batch(
                "worker-a", now=self.now, lease_seconds=120
            )
            reclaimed_at = datetime(2026, 9, 22, 12, 2, 1, tzinfo=timezone.utc)
            reclaimed = outbox_relay_service.claim_outbox_batch(
                "worker-b", now=reclaimed_at, lease_seconds=120
            )
            self.assertEqual(len(reclaimed), 1)
            self.assertEqual(reclaimed[0].event_id, first[0].event_id)
            self.assertEqual(reclaimed[0].attempt_count, 2)


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
