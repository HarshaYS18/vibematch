import json
from pathlib import Path
from unittest import TestCase

from redis.exceptions import ConnectionError

from app.core.config import Settings
from app.realtime.connection_manager import has_active_room_user_lease


ROOT = Path(__file__).resolve().parents[2]


def _safe_production_settings(**overrides):
    values = dict(
        APP_ENV="production",
        JWT_SECRET_KEY="j" * 40,
        MEDIA_INTERNAL_TOKEN="m" * 40,
        INBOX_BACKUP_ENCRYPTION_KEY="b" * 40,
        GOOGLE_AUTH_CLIENT_IDS="client.apps.googleusercontent.com",
        REALTIME_CAPABILITY_PRIVATE_KEY_B64="AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
        CORS_ALLOWED_ORIGINS="https://funkey.example",
        MEDIA_STORAGE_DRIVER="s3",
        MEDIA_S3_BUCKET="bucket",
        MEDIA_CDN_BASE_URL="https://cdn.funkey.example",
        RATE_LIMIT_ENABLED=True,
        database_url="postgresql://funkey:strong-secret@postgres.internal:5432/funkey",
        CACHE_REDIS_URL="rediss://cache.internal:6379/0",
        REALTIME_REDIS_URL="rediss://realtime.internal:6379/0",
        MEDIA_REGISTRY_REDIS_URL="rediss://media.internal:6379/0",
    )
    values.update(overrides)
    return Settings(**values, _env_file=None)


class RedisPlatformContractTests(TestCase):
    def test_machine_contract_has_three_non_authoritative_roles(self):
        contract = json.loads(
            (ROOT / "contracts/redis/topology.json").read_text(encoding="utf-8")
        )
        self.assertEqual("EPHEMERAL_OR_CACHE_ONLY", contract["authority"])
        self.assertEqual(
            {"app_cache_rate_limit", "realtime_presence", "media_registry"},
            set(contract["roles"]),
        )
        for role in contract["roles"].values():
            self.assertTrue(role["ha_required"])
            self.assertTrue(role["maxmemory_required"])
            self.assertTrue(role["ttl_required_for_business_keys"])
            self.assertFalse(role["redis_cluster_supported_by_current_client"])

    def test_production_requires_distinct_role_endpoints(self):
        _safe_production_settings().validate_production()
        with self.assertRaisesRegex(RuntimeError, "Redis role endpoint separation"):
            _safe_production_settings(
                REALTIME_REDIS_URL="rediss://cache.internal:6379/4"
            ).validate_production()
        with self.assertRaisesRegex(RuntimeError, "MEDIA_REGISTRY_REDIS_URL"):
            _safe_production_settings(MEDIA_REGISTRY_REDIS_URL="").validate_production()

    def test_runtime_routes_use_their_owned_redis_roles(self):
        redis_client = (ROOT / "backend/app/core/redis_client.py").read_text(encoding="utf-8")
        realtime = (ROOT / "backend/app/realtime/connection_manager.py").read_text(encoding="utf-8")
        media = (ROOT / "backend/app/api/routes/media_control.py").read_text(encoding="utf-8")
        self.assertIn("settings.cache_redis_url", redis_client)
        self.assertIn("settings.realtime_redis_url", redis_client)
        self.assertIn("settings.media_registry_redis_url", redis_client)
        self.assertIn('funkey:realtime:room', realtime)
        self.assertIn("settings.realtime_redis_url", realtime)
        self.assertIn("get_realtime_redis", media)
        self.assertIn("get_media_registry_redis", media)

    def test_ttl_contract_matches_implementation(self):
        contract = json.loads(
            (ROOT / "contracts/redis/topology.json").read_text(encoding="utf-8")
        )["ttl_seconds"]
        realtime = (ROOT / "backend/app/realtime/connection_manager.py").read_text(encoding="utf-8")
        rate_limit = (ROOT / "backend/app/core/rate_limit.py").read_text(encoding="utf-8")
        gateway = (ROOT / "apps/realtime-gateway/internal/gateway/config.go").read_text(encoding="utf-8")
        self.assertIn(f'_SOCKET_LEASE_SECONDS = {contract["fastapi_socket_lease_score"]}', realtime)
        self.assertIn(
            f'_COMMAND_CLAIM_SECONDS = {contract["realtime_command_dedupe"] // 60} * 60',
            realtime,
        )
        self.assertIn(str(contract["rate_limit_window_key"] * 1000), rate_limit)
        self.assertIn(
            f'LeaseTTL:              {contract["realtime_gateway_lease"]} * time.Second',
            gateway,
        )

    def test_local_topology_has_role_specific_memory_policies(self):
        compose = (ROOT / "infra/docker-compose.yml").read_text(encoding="utf-8")
        self.assertIn("cache-redis:", compose)
        self.assertIn("realtime-redis:", compose)
        self.assertIn("media-redis:", compose)
        self.assertIn("allkeys-lfu", compose)
        self.assertIn("volatile-ttl", compose)
        self.assertIn("noeviction", compose)

    def test_redis_loss_cannot_grant_room_presence(self):
        class OfflineRedis:
            def zcount(self, *_args, **_kwargs):
                raise ConnectionError("offline")

        self.assertFalse(has_active_room_user_lease(OfflineRedis(), "ROOM1", 7))
