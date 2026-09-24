from urllib.parse import urlsplit

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "FunKey"
    APP_ENV: str = "development"
    ENFORCE_SCHEMA_CURRENT: bool = True
    CORS_ALLOWED_ORIGINS: str = "*"

    # OpenTelemetry tracing is opt-in locally and enabled by deployment config.
    # Export failure is never a readiness or business-transaction dependency.
    OTEL_TRACES_ENABLED: bool = False
    OTEL_EXPORTER_OTLP_TRACES_ENDPOINT: str = "http://127.0.0.1:4318/v1/traces"
    OTEL_TRACE_SAMPLE_RATIO: float = 0.10
    OTEL_EXPORT_TIMEOUT_SECONDS: float = 3.0
    OTEL_BSP_MAX_QUEUE_SIZE: int = 2048
    OTEL_BSP_MAX_EXPORT_BATCH_SIZE: int = 512
    OTEL_BSP_SCHEDULE_DELAY_MS: int = 5000
    DB_QUERY_COUNT_RESPONSE_HEADER: bool = False

    # Database / Redis from .env
    database_url: str = "postgresql://postgres:postgres@localhost:5432/vibematch"
    MIGRATION_DATABASE_URL: str = ""
    # Legacy redis_url remains a development fallback for the application
    # cache/rate-limit role only. Production must provide all three explicit
    # role endpoints so cache pressure cannot destabilize realtime/media.
    redis_url: str = "redis://localhost:6379/0"
    CACHE_REDIS_URL: str = ""
    REALTIME_REDIS_URL: str = ""
    MEDIA_REGISTRY_REDIS_URL: str = ""
    REDIS_CONNECT_TIMEOUT_SECONDS: float = 2.0
    REDIS_SOCKET_TIMEOUT_SECONDS: float = 2.0
    CACHE_REDIS_MAX_CONNECTIONS: int = 50
    REALTIME_REDIS_MAX_CONNECTIONS: int = 100
    MEDIA_REGISTRY_REDIS_MAX_CONNECTIONS: int = 30

    # PostgreSQL / PgBouncer platform policy.
    DB_POOLER_MODE: str = "direct"
    DB_APPLICATION_NAME: str = "funkey-api"
    DB_LOCK_TIMEOUT_MS: int = 1000
    DB_STATEMENT_TIMEOUT_MS: int = 3000
    DB_IDLE_IN_TRANSACTION_SESSION_TIMEOUT_MS: int = 10000
    DB_SLOW_QUERY_MS: int = 500
    DB_CONNECT_TIMEOUT_SECONDS: int = 5
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 0
    DB_POOL_TIMEOUT_SECONDS: int = 3
    DB_POOL_RECYCLE_SECONDS: int = 1800
    DB_POOL_USE_LIFO: bool = True
    # Read replicas remain opt-in. No route is approved until measured,
    # stale-tolerant routing is documented in the database storage policy.
    DB_READ_REPLICA_ENABLED: bool = False
    READ_REPLICA_DATABASE_URL: str = ""

    # Chunk 23 Inbox service boundary.
    INBOX_SERVICE_URL: str = "http://127.0.0.1:8083/api/v1"
    INBOX_INTERNAL_URL: str = "http://127.0.0.1:8083/internal/inbox"
    INBOX_SERVICE_TIMEOUT_SECONDS: float = 5.0
    INBOX_INTERNAL_TOKEN: str = "change-this-inbox-internal-token"
    INBOX_DATABASE_URL: str = ""
    INBOX_DB_POOL_SIZE: int = 5
    INBOX_DB_MAX_OVERFLOW: int = 0
    INBOX_DB_POOL_TIMEOUT_SECONDS: int = 3
    INBOX_MAX_REPLICAS: int = 20
    DB_INBOX_CONNECTION_BUDGET: int = 100
    INBOX_REALTIME_TRANSPORT: str = "redis"
    INBOX_NATS_SUBJECT: str = "funkey.events.inbox.realtime"
    NATS_URL: str = "nats://127.0.0.1:4222"

    # Chunk 24 Vibes service boundary.
    VIBES_SERVICE_URL: str = "http://127.0.0.1:8084/api/v1"
    VIBES_INTERNAL_URL: str = "http://127.0.0.1:8084/internal/vibes"
    VIBES_SERVICE_TIMEOUT_SECONDS: float = 5.0
    VIBES_INTERNAL_TOKEN: str = "change-this-vibes-internal-token"
    VIBES_DATABASE_URL: str = ""
    VIBES_DB_POOL_SIZE: int = 5
    VIBES_DB_MAX_OVERFLOW: int = 0
    VIBES_DB_POOL_TIMEOUT_SECONDS: int = 3
    VIBES_MAX_REPLICAS: int = 20
    DB_VIBES_CONNECTION_BUDGET: int = 100

    # Chunk 26 Room Control service boundary.
    ROOM_CONTROL_SERVICE_URL: str = "http://127.0.0.1:8085/api/v1"
    ROOM_CONTROL_INTERNAL_URL: str = "http://127.0.0.1:8085/internal/room-control"
    ROOM_CONTROL_SERVICE_TIMEOUT_SECONDS: float = 5.0
    ROOM_CONTROL_INTERNAL_TOKEN: str = "change-this-room-control-internal-token"
    ROOM_CONTROL_DATABASE_URL: str = ""
    ROOM_CONTROL_DB_POOL_SIZE: int = 3
    ROOM_CONTROL_DB_MAX_OVERFLOW: int = 0
    ROOM_CONTROL_DB_POOL_TIMEOUT_SECONDS: int = 3
    ROOM_CONTROL_MAX_REPLICAS: int = 20
    DB_ROOM_CONTROL_CONNECTION_BUDGET: int = 60

    # Chunk 27 Identity / Profile-Social service boundaries.
    IDENTITY_SERVICE_URL: str = "http://127.0.0.1:8086/api/v1"
    IDENTITY_INTERNAL_URL: str = "http://127.0.0.1:8086/internal/identity"
    IDENTITY_SERVICE_TIMEOUT_SECONDS: float = 5.0
    IDENTITY_INTERNAL_TOKEN: str = "change-this-identity-internal-token"
    IDENTITY_DATABASE_URL: str = ""
    IDENTITY_DB_POOL_SIZE: int = 3
    IDENTITY_DB_MAX_OVERFLOW: int = 0
    IDENTITY_DB_POOL_TIMEOUT_SECONDS: int = 3
    IDENTITY_MAX_REPLICAS: int = 20
    DB_IDENTITY_CONNECTION_BUDGET: int = 60

    PROFILE_SOCIAL_SERVICE_URL: str = "http://127.0.0.1:8087/api/v1"
    PROFILE_SOCIAL_INTERNAL_URL: str = "http://127.0.0.1:8087/internal/profile-social"
    PROFILE_SOCIAL_SERVICE_TIMEOUT_SECONDS: float = 5.0
    PROFILE_SOCIAL_INTERNAL_TOKEN: str = "change-this-profile-social-internal-token"
    PROFILE_SOCIAL_DATABASE_URL: str = ""
    PROFILE_SOCIAL_DB_POOL_SIZE: int = 4
    PROFILE_SOCIAL_DB_MAX_OVERFLOW: int = 0
    PROFILE_SOCIAL_DB_POOL_TIMEOUT_SECONDS: int = 3
    PROFILE_SOCIAL_MAX_REPLICAS: int = 20
    DB_PROFILE_SOCIAL_CONNECTION_BUDGET: int = 80

    # Restored Chunk 25 Economy service boundary.
    ECONOMY_SERVICE_URL: str = "http://127.0.0.1:8088/api/v1"
    ECONOMY_INTERNAL_URL: str = "http://127.0.0.1:8088/internal/economy"
    ECONOMY_SERVICE_TIMEOUT_SECONDS: float = 5.0
    ECONOMY_INTERNAL_TOKEN: str = "change-this-economy-internal-token"
    ECONOMY_DATABASE_URL: str = ""
    ECONOMY_DB_POOL_SIZE: int = 4
    ECONOMY_DB_MAX_OVERFLOW: int = 0
    ECONOMY_DB_POOL_TIMEOUT_SECONDS: int = 3
    ECONOMY_MAX_REPLICAS: int = 20
    DB_ECONOMY_CONNECTION_BUDGET: int = 80
    ECONOMY_BULK_BATCH_SIZE: int = 500
    ECONOMY_BULK_LEASE_SECONDS: int = 120
    ECONOMY_BULK_POLL_SECONDS: float = 1.0
    ECONOMY_BULK_WORKER_DB_POOL_SIZE: int = 2
    ECONOMY_BULK_WORKER_DB_MAX_OVERFLOW: int = 0
    ECONOMY_BULK_WORKER_MAX_REPLICAS: int = 4
    DB_ECONOMY_BULK_WORKER_CONNECTION_BUDGET: int = 8

    # Chunk 28 Game Platform service boundary.
    GAME_PLATFORM_SERVICE_URL: str = "http://127.0.0.1:8089/api/v1"
    GAME_PLATFORM_SERVICE_TIMEOUT_SECONDS: float = 5.0
    GAME_PLATFORM_DATABASE_URL: str = ""
    GAME_PLATFORM_DB_POOL_SIZE: int = 4
    GAME_PLATFORM_DB_MAX_OVERFLOW: int = 0
    GAME_PLATFORM_DB_POOL_TIMEOUT_SECONDS: int = 3
    GAME_PLATFORM_MAX_REPLICAS: int = 20
    DB_GAME_PLATFORM_CONNECTION_BUDGET: int = 80

    # Topology budgets. These are planning/validation limits, not capacity claims.
    API_MAX_REPLICAS: int = 20
    DB_API_CONNECTION_BUDGET: int = 100
    WORKER_MAX_REPLICAS: int = 20
    DB_WORKER_POOL_SIZE: int = 3
    DB_WORKER_MAX_OVERFLOW: int = 0
    DB_WORKER_CONNECTION_BUDGET: int = 60
    DB_ROLLOUT_SURGE_CONNECTION_RESERVE: int = 20
    DB_POOLER_MAX_CLIENT_CONNECTIONS: int = 800
    DB_SERVER_CONNECTION_LIMIT: int = 160
    DB_POOLER_MAX_SERVER_CONNECTIONS: int = 120
    DB_DIRECT_CONNECTION_RESERVE: int = 40

    # Media control plane / node registry
    MEDIA_INTERNAL_TOKEN: str = "change-this-media-internal-token"
    MEDIA_NODE_TTL_SECONDS: int = 30
    MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS: int = 86400
    MEDIA_REGISTRY_TRACE: bool = False

    # JWT
    JWT_SECRET_KEY: str = "change-this-secret-key-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Chunk 22 realtime capabilities. The API alone owns the Ed25519 private
    # key; the Go gateway fetches only the public key and verifies locally.
    REALTIME_CAPABILITY_PRIVATE_KEY_B64: str = ""
    REALTIME_CAPABILITY_KEY_ID: str = "funkey-realtime-v1"
    REALTIME_CAPABILITY_ISSUER: str = "funkey-api"
    REALTIME_CAPABILITY_AUDIENCE: str = "funkey-realtime"
    REALTIME_CAPABILITY_TTL_SECONDS: int = 300
    REALTIME_CAPABILITY_TOKEN_VERSION: int = 1

    # Founder Owner
    FOUNDER_OWNER_PUBLIC_ID: int = 6922022
    FOUNDER_OWNER_EMAIL: str = "founder@vibematch.com"

    # Dynamic gift assets. In production set this to your CDN.
    GIFT_CDN_BASE_URL: str = ""

    # Production media storage.
    # local = dev/testing only. s3 = Oracle Object Storage S3-compatible API,
    # AWS S3, Cloudflare R2, MinIO, or any S3-compatible bucket.
    MEDIA_STORAGE_DRIVER: str = "local"
    MEDIA_CDN_BASE_URL: str = ""
    MEDIA_S3_BUCKET: str = ""
    MEDIA_S3_REGION: str = ""
    MEDIA_S3_ENDPOINT_URL: str = ""
    MEDIA_S3_ACCESS_KEY_ID: str = ""
    MEDIA_S3_SECRET_ACCESS_KEY: str = ""
    MEDIA_S3_PUBLIC_READ: bool = True

    # Google Sign-In OAuth client IDs. Comma-separated for web/android/ios clients.
    GOOGLE_AUTH_CLIENT_IDS: str = ""
    ENABLE_DEV_LOGIN: bool = False
    RATE_LIMIT_ENABLED: bool = False
    TRUSTED_PROXY_CIDRS: str = ""
    MAX_REQUEST_BYTES: int = 26 * 1024 * 1024
    DRAIN_MARKER_PATH: str = "/tmp/funkey-api-draining"

    # Google Drive backup OAuth
    GOOGLE_DRIVE_CLIENT_ID: str = ""
    GOOGLE_DRIVE_CLIENT_SECRET: str = ""
    GOOGLE_DRIVE_REDIRECT_URI: str = "http://127.0.0.1:8000/api/v1/inbox/backup/google/callback"
    GOOGLE_DRIVE_SCOPES: str = "https://www.googleapis.com/auth/drive.file"
    INBOX_BACKUP_ENCRYPTION_KEY: str = "change-this-32-byte-key-before-production"

    # Firebase Cloud Messaging HTTP v1
    FCM_PROJECT_ID: str = ""
    FIREBASE_SERVICE_ACCOUNT_PATH: str = ""

    @property
    def cors_allowed_origins(self) -> list[str]:
        raw = self.CORS_ALLOWED_ORIGINS.strip()
        if not raw or raw == "*":
            return ["*"]
        return [origin.strip() for origin in raw.split(",") if origin.strip()]

    @property
    def is_production(self) -> bool:
        return self.APP_ENV.lower() in {"production", "prod"}

    @property
    def migration_database_url(self) -> str:
        return self.MIGRATION_DATABASE_URL.strip() or self.database_url

    @property
    def cache_redis_url(self) -> str:
        return self.CACHE_REDIS_URL.strip() or self.redis_url

    @property
    def realtime_redis_url(self) -> str:
        return self.REALTIME_REDIS_URL.strip() or self.cache_redis_url

    @property
    def media_registry_redis_url(self) -> str:
        return self.MEDIA_REGISTRY_REDIS_URL.strip() or self.cache_redis_url

    @staticmethod
    def _redis_endpoint_identity(value: str) -> tuple[str, int | None]:
        parsed = urlsplit(value)
        try:
            port = parsed.port
        except ValueError:
            port = None
        return parsed.hostname or "", port

    @property
    def expected_pooler_client_connections(self) -> int:
        return (
            self.DB_API_CONNECTION_BUDGET
            + self.DB_INBOX_CONNECTION_BUDGET
            + self.DB_VIBES_CONNECTION_BUDGET
            + self.DB_ROOM_CONTROL_CONNECTION_BUDGET
            + self.DB_IDENTITY_CONNECTION_BUDGET
            + self.DB_PROFILE_SOCIAL_CONNECTION_BUDGET
            + self.DB_ECONOMY_CONNECTION_BUDGET
            + self.DB_ECONOMY_BULK_WORKER_CONNECTION_BUDGET
            + self.DB_GAME_PLATFORM_CONNECTION_BUDGET
            + self.DB_WORKER_CONNECTION_BUDGET
            + self.DB_ROLLOUT_SURGE_CONNECTION_RESERVE
        )

    def validate_production(self) -> None:
        """Reject unsafe deploys before the application accepts traffic."""
        if not self.is_production:
            return
        unsafe = []
        for name in (
            "JWT_SECRET_KEY",
            "MEDIA_INTERNAL_TOKEN",
            "INBOX_BACKUP_ENCRYPTION_KEY",
            "INBOX_INTERNAL_TOKEN",
            "ROOM_CONTROL_INTERNAL_TOKEN",
            "IDENTITY_INTERNAL_TOKEN",
            "PROFILE_SOCIAL_INTERNAL_TOKEN",
            "ECONOMY_INTERNAL_TOKEN",
        ):
            value = getattr(self, name).strip()
            if len(value) < 32 or "change-this" in value.lower():
                unsafe.append(name)
        if self.ENABLE_DEV_LOGIN:
            unsafe.append("ENABLE_DEV_LOGIN")
        if self.JWT_ALGORITHM not in {"HS256", "HS384", "HS512"}:
            unsafe.append("JWT_ALGORITHM")
        if not self.REALTIME_CAPABILITY_PRIVATE_KEY_B64.strip():
            unsafe.append("REALTIME_CAPABILITY_PRIVATE_KEY_B64")
        if not self.REALTIME_CAPABILITY_KEY_ID.strip():
            unsafe.append("REALTIME_CAPABILITY_KEY_ID")
        if not self.REALTIME_CAPABILITY_ISSUER.strip():
            unsafe.append("REALTIME_CAPABILITY_ISSUER")
        if not self.REALTIME_CAPABILITY_AUDIENCE.strip():
            unsafe.append("REALTIME_CAPABILITY_AUDIENCE")
        if not 60 <= self.REALTIME_CAPABILITY_TTL_SECONDS <= 600:
            unsafe.append("REALTIME_CAPABILITY_TTL_SECONDS")
        if self.REALTIME_CAPABILITY_TOKEN_VERSION < 1:
            unsafe.append("REALTIME_CAPABILITY_TOKEN_VERSION")

        db_url = urlsplit(self.database_url)
        if not db_url.scheme.startswith("postgresql") or not db_url.hostname:
            unsafe.append("database_url")
        if self.database_url == "postgresql://postgres:postgres@localhost:5432/vibematch":
            unsafe.append("database_url(default)")
        if self.DB_POOLER_MODE not in {"direct", "transaction"}:
            unsafe.append("DB_POOLER_MODE")
        if self.DB_READ_REPLICA_ENABLED:
            replica_url = self.READ_REPLICA_DATABASE_URL.strip()
            if not replica_url or replica_url == self.database_url:
                unsafe.append("READ_REPLICA_DATABASE_URL")
            else:
                parsed_replica = urlsplit(replica_url)
                if (
                    not parsed_replica.scheme.startswith("postgresql")
                    or not parsed_replica.hostname
                ):
                    unsafe.append("READ_REPLICA_DATABASE_URL")
        if self.DB_POOLER_MODE == "transaction":
            migration_url = self.MIGRATION_DATABASE_URL.strip()
            if not migration_url or migration_url == self.database_url:
                unsafe.append("MIGRATION_DATABASE_URL")
            else:
                parsed_migration = urlsplit(migration_url)
                if not parsed_migration.scheme.startswith("postgresql") or not parsed_migration.hostname:
                    unsafe.append("MIGRATION_DATABASE_URL")

        explicit_redis_urls = {
            "CACHE_REDIS_URL": self.CACHE_REDIS_URL.strip(),
            "REALTIME_REDIS_URL": self.REALTIME_REDIS_URL.strip(),
            "MEDIA_REGISTRY_REDIS_URL": self.MEDIA_REGISTRY_REDIS_URL.strip(),
        }
        redis_identities = []
        for name, value in explicit_redis_urls.items():
            if not value:
                unsafe.append(name)
                continue
            parsed = urlsplit(value)
            if parsed.scheme not in {"redis", "rediss"} or not parsed.hostname:
                unsafe.append(name)
                continue
            redis_identities.append(self._redis_endpoint_identity(value))
        if len(redis_identities) == 3 and len(set(redis_identities)) != 3:
            unsafe.append("Redis role endpoint separation")
        if (
            self.CACHE_REDIS_MAX_CONNECTIONS < 1
            or self.REALTIME_REDIS_MAX_CONNECTIONS < 1
            or self.MEDIA_REGISTRY_REDIS_MAX_CONNECTIONS < 1
        ):
            unsafe.append("Redis connection budgets")
        if not self.GOOGLE_AUTH_CLIENT_IDS.strip():
            unsafe.append("GOOGLE_AUTH_CLIENT_IDS")
        if self.cors_allowed_origins == ["*"] or any(origin == "*" for origin in self.cors_allowed_origins):
            unsafe.append("CORS_ALLOWED_ORIGINS")
        elif any(not origin.startswith("https://") for origin in self.cors_allowed_origins):
            unsafe.append("CORS_ALLOWED_ORIGINS(https)")
        if self.MEDIA_STORAGE_DRIVER.lower() != "s3" or not self.MEDIA_S3_BUCKET or not self.MEDIA_CDN_BASE_URL:
            unsafe.append("MEDIA_STORAGE_DRIVER/MEDIA_S3_BUCKET/MEDIA_CDN_BASE_URL")
        elif not self.MEDIA_CDN_BASE_URL.startswith("https://"):
            unsafe.append("MEDIA_CDN_BASE_URL(https)")
        if self.MEDIA_S3_ENDPOINT_URL and not self.MEDIA_S3_ENDPOINT_URL.startswith("https://"):
            unsafe.append("MEDIA_S3_ENDPOINT_URL(https)")
        if not self.RATE_LIMIT_ENABLED:
            unsafe.append("RATE_LIMIT_ENABLED")

        if (
            self.DB_POOL_SIZE < 1
            or self.DB_MAX_OVERFLOW < 0
            or self.API_MAX_REPLICAS < 3
            or self.DB_WORKER_POOL_SIZE < 1
            or self.DB_WORKER_MAX_OVERFLOW < 0
            or self.WORKER_MAX_REPLICAS < 1
        ):
            unsafe.append("DB_POOL_SIZE/DB_MAX_OVERFLOW/replica budgets")
        if self.API_MAX_REPLICAS * (self.DB_POOL_SIZE + self.DB_MAX_OVERFLOW) > self.DB_API_CONNECTION_BUDGET:
            unsafe.append("DB_API_CONNECTION_BUDGET")
        if not self.INBOX_SERVICE_URL.strip():
            unsafe.append("INBOX_SERVICE_URL")
        if not self.INBOX_INTERNAL_URL.strip():
            unsafe.append("INBOX_INTERNAL_URL")
        if self.INBOX_DB_POOL_SIZE <= 0 or self.INBOX_DB_MAX_OVERFLOW < 0:
            unsafe.append("INBOX_DB_POOL_SIZE/INBOX_DB_MAX_OVERFLOW")
        if (
            self.INBOX_MAX_REPLICAS
            * (self.INBOX_DB_POOL_SIZE + self.INBOX_DB_MAX_OVERFLOW)
            > self.DB_INBOX_CONNECTION_BUDGET
        ):
            unsafe.append("DB_INBOX_CONNECTION_BUDGET")
        if not self.VIBES_SERVICE_URL.strip():
            unsafe.append("VIBES_SERVICE_URL")
        if not self.VIBES_INTERNAL_URL.strip():
            unsafe.append("VIBES_INTERNAL_URL")
        if self.VIBES_DB_POOL_SIZE <= 0 or self.VIBES_DB_MAX_OVERFLOW < 0:
            unsafe.append("VIBES_DB_POOL_SIZE/VIBES_DB_MAX_OVERFLOW")
        if (
            self.VIBES_MAX_REPLICAS
            * (self.VIBES_DB_POOL_SIZE + self.VIBES_DB_MAX_OVERFLOW)
            > self.DB_VIBES_CONNECTION_BUDGET
        ):
            unsafe.append("DB_VIBES_CONNECTION_BUDGET")
        if not self.ROOM_CONTROL_SERVICE_URL.strip():
            unsafe.append("ROOM_CONTROL_SERVICE_URL")
        if not self.ROOM_CONTROL_INTERNAL_URL.strip():
            unsafe.append("ROOM_CONTROL_INTERNAL_URL")
        if self.ROOM_CONTROL_DB_POOL_SIZE <= 0 or self.ROOM_CONTROL_DB_MAX_OVERFLOW < 0:
            unsafe.append("ROOM_CONTROL_DB_POOL_SIZE/ROOM_CONTROL_DB_MAX_OVERFLOW")
        if (
            self.ROOM_CONTROL_MAX_REPLICAS
            * (self.ROOM_CONTROL_DB_POOL_SIZE + self.ROOM_CONTROL_DB_MAX_OVERFLOW)
            > self.DB_ROOM_CONTROL_CONNECTION_BUDGET
        ):
            unsafe.append("DB_ROOM_CONTROL_CONNECTION_BUDGET")
        if self.WORKER_MAX_REPLICAS * (
            self.DB_WORKER_POOL_SIZE + self.DB_WORKER_MAX_OVERFLOW
        ) > self.DB_WORKER_CONNECTION_BUDGET:
            unsafe.append("DB_WORKER_CONNECTION_BUDGET")
        if self.expected_pooler_client_connections > self.DB_POOLER_MAX_CLIENT_CONNECTIONS:
            unsafe.append("DB_POOLER_MAX_CLIENT_CONNECTIONS")
        if (
            self.DB_POOLER_MAX_SERVER_CONNECTIONS < 1
            or self.DB_DIRECT_CONNECTION_RESERVE < 1
            or self.DB_POOLER_MAX_SERVER_CONNECTIONS + self.DB_DIRECT_CONNECTION_RESERVE
            > self.DB_SERVER_CONNECTION_LIMIT
        ):
            unsafe.append("DB_SERVER_CONNECTION_LIMIT")
        if (
            self.DB_LOCK_TIMEOUT_MS <= 0
            or self.DB_STATEMENT_TIMEOUT_MS <= 0
            or self.DB_IDLE_IN_TRANSACTION_SESSION_TIMEOUT_MS <= 0
            or self.DB_SLOW_QUERY_MS <= 0
            or self.DB_CONNECT_TIMEOUT_SECONDS <= 0
            or self.DB_POOL_TIMEOUT_SECONDS <= 0
        ):
            unsafe.append("database timeouts")

        if self.OTEL_TRACES_ENABLED:
            if not self.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT.startswith(("http://", "https://")):
                unsafe.append("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
            if not 0.0 <= self.OTEL_TRACE_SAMPLE_RATIO <= 1.0:
                unsafe.append("OTEL_TRACE_SAMPLE_RATIO")
        if unsafe:
            raise RuntimeError("Unsafe production configuration: " + ", ".join(unsafe))

    def validate_inbox_service(self) -> None:
        """Validate settings that belong only to the extracted Inbox deployable."""

        if not self.is_production:
            return
        unsafe: list[str] = []
        if (
            len(self.INBOX_INTERNAL_TOKEN.strip()) < 32
            or "change-this" in self.INBOX_INTERNAL_TOKEN.lower()
        ):
            unsafe.append("INBOX_INTERNAL_TOKEN")
        inbox_url = self.INBOX_DATABASE_URL.strip()
        if not inbox_url:
            unsafe.append("INBOX_DATABASE_URL")
        elif inbox_url == self.database_url.strip():
            unsafe.append("INBOX_DATABASE_URL(service-isolated credentials required)")
        if self.INBOX_REALTIME_TRANSPORT.strip().lower() != "nats":
            unsafe.append("INBOX_REALTIME_TRANSPORT(nats required)")
        if not self.NATS_URL.strip():
            unsafe.append("NATS_URL")
        if not self.INBOX_NATS_SUBJECT.strip():
            unsafe.append("INBOX_NATS_SUBJECT")
        if self.INBOX_DB_POOL_SIZE <= 0 or self.INBOX_DB_MAX_OVERFLOW < 0:
            unsafe.append("INBOX_DB_POOL_SIZE/INBOX_DB_MAX_OVERFLOW")
        if (
            self.INBOX_MAX_REPLICAS
            * (self.INBOX_DB_POOL_SIZE + self.INBOX_DB_MAX_OVERFLOW)
            > self.DB_INBOX_CONNECTION_BUDGET
        ):
            unsafe.append("DB_INBOX_CONNECTION_BUDGET")
        if unsafe:
            raise RuntimeError(
                "Unsafe Inbox service production configuration: "
                + ", ".join(unsafe)
            )

    def validate_vibes_service(self) -> None:
        """Validate settings owned by the extracted Vibes deployable."""

        if not self.is_production:
            return
        unsafe: list[str] = []
        if (
            len(self.VIBES_INTERNAL_TOKEN.strip()) < 32
            or "change-this" in self.VIBES_INTERNAL_TOKEN.lower()
        ):
            unsafe.append("VIBES_INTERNAL_TOKEN")
        vibes_url = self.VIBES_DATABASE_URL.strip()
        if not vibes_url:
            unsafe.append("VIBES_DATABASE_URL")
        elif vibes_url == self.database_url.strip():
            unsafe.append("VIBES_DATABASE_URL(service-isolated credentials required)")
        if self.VIBES_DB_POOL_SIZE <= 0 or self.VIBES_DB_MAX_OVERFLOW < 0:
            unsafe.append("VIBES_DB_POOL_SIZE/VIBES_DB_MAX_OVERFLOW")
        if (
            self.VIBES_MAX_REPLICAS
            * (self.VIBES_DB_POOL_SIZE + self.VIBES_DB_MAX_OVERFLOW)
            > self.DB_VIBES_CONNECTION_BUDGET
        ):
            unsafe.append("DB_VIBES_CONNECTION_BUDGET")
        if unsafe:
            raise RuntimeError(
                "Unsafe Vibes service production configuration: "
                + ", ".join(unsafe)
            )

    def validate_room_control_service(self) -> None:
        """Validate settings owned by the extracted Room Control deployable."""

        if not self.is_production:
            return
        unsafe: list[str] = []
        if (
            len(self.ROOM_CONTROL_INTERNAL_TOKEN.strip()) < 32
            or "change-this" in self.ROOM_CONTROL_INTERNAL_TOKEN.lower()
        ):
            unsafe.append("ROOM_CONTROL_INTERNAL_TOKEN")
        room_url = self.ROOM_CONTROL_DATABASE_URL.strip()
        if not room_url:
            unsafe.append("ROOM_CONTROL_DATABASE_URL")
        elif room_url == self.database_url.strip():
            unsafe.append("ROOM_CONTROL_DATABASE_URL(service-isolated credentials required)")
        if self.ROOM_CONTROL_DB_POOL_SIZE <= 0 or self.ROOM_CONTROL_DB_MAX_OVERFLOW < 0:
            unsafe.append("ROOM_CONTROL_DB_POOL_SIZE/ROOM_CONTROL_DB_MAX_OVERFLOW")
        if (
            self.ROOM_CONTROL_MAX_REPLICAS
            * (self.ROOM_CONTROL_DB_POOL_SIZE + self.ROOM_CONTROL_DB_MAX_OVERFLOW)
            > self.DB_ROOM_CONTROL_CONNECTION_BUDGET
        ):
            unsafe.append("DB_ROOM_CONTROL_CONNECTION_BUDGET")
        if unsafe:
            raise RuntimeError(
                "Unsafe Room Control production configuration: "
                + ", ".join(unsafe)
            )

    def validate_identity_service(self) -> None:
        """Validate settings owned by the extracted Identity deployable."""
        if not self.is_production:
            return
        unsafe: list[str] = []
        if len(self.IDENTITY_INTERNAL_TOKEN.strip()) < 32 or "change-this" in self.IDENTITY_INTERNAL_TOKEN.lower():
            unsafe.append("IDENTITY_INTERNAL_TOKEN")
        url = self.IDENTITY_DATABASE_URL.strip()
        if not url:
            unsafe.append("IDENTITY_DATABASE_URL")
        elif url == self.database_url.strip():
            unsafe.append("IDENTITY_DATABASE_URL(service-isolated credentials required)")
        if self.IDENTITY_DB_POOL_SIZE <= 0 or self.IDENTITY_DB_MAX_OVERFLOW < 0:
            unsafe.append("IDENTITY_DB_POOL_SIZE/IDENTITY_DB_MAX_OVERFLOW")
        if self.IDENTITY_MAX_REPLICAS * (self.IDENTITY_DB_POOL_SIZE + self.IDENTITY_DB_MAX_OVERFLOW) > self.DB_IDENTITY_CONNECTION_BUDGET:
            unsafe.append("DB_IDENTITY_CONNECTION_BUDGET")
        if unsafe:
            raise RuntimeError("Unsafe Identity service production configuration: " + ", ".join(unsafe))

    def validate_profile_social_service(self) -> None:
        """Validate settings owned by the extracted Profile/Social deployable."""
        if not self.is_production:
            return
        unsafe: list[str] = []
        if len(self.PROFILE_SOCIAL_INTERNAL_TOKEN.strip()) < 32 or "change-this" in self.PROFILE_SOCIAL_INTERNAL_TOKEN.lower():
            unsafe.append("PROFILE_SOCIAL_INTERNAL_TOKEN")
        url = self.PROFILE_SOCIAL_DATABASE_URL.strip()
        if not url:
            unsafe.append("PROFILE_SOCIAL_DATABASE_URL")
        elif url == self.database_url.strip():
            unsafe.append("PROFILE_SOCIAL_DATABASE_URL(service-isolated credentials required)")
        if self.PROFILE_SOCIAL_DB_POOL_SIZE <= 0 or self.PROFILE_SOCIAL_DB_MAX_OVERFLOW < 0:
            unsafe.append("PROFILE_SOCIAL_DB_POOL_SIZE/PROFILE_SOCIAL_DB_MAX_OVERFLOW")
        if self.PROFILE_SOCIAL_MAX_REPLICAS * (self.PROFILE_SOCIAL_DB_POOL_SIZE + self.PROFILE_SOCIAL_DB_MAX_OVERFLOW) > self.DB_PROFILE_SOCIAL_CONNECTION_BUDGET:
            unsafe.append("DB_PROFILE_SOCIAL_CONNECTION_BUDGET")
        if unsafe:
            raise RuntimeError("Unsafe Profile/Social service production configuration: " + ", ".join(unsafe))

    def validate_economy_service(self) -> None:
        """Validate Tier-0 Economy service production isolation."""
        if not self.is_production:
            return
        unsafe: list[str] = []
        if len(self.ECONOMY_INTERNAL_TOKEN.strip()) < 32 or "change-this" in self.ECONOMY_INTERNAL_TOKEN.lower():
            unsafe.append("ECONOMY_INTERNAL_TOKEN")
        url = self.ECONOMY_DATABASE_URL.strip()
        if not url:
            unsafe.append("ECONOMY_DATABASE_URL")
        elif url == self.database_url.strip():
            unsafe.append("ECONOMY_DATABASE_URL(service-isolated credentials required)")
        if self.ECONOMY_DB_POOL_SIZE <= 0 or self.ECONOMY_DB_MAX_OVERFLOW < 0:
            unsafe.append("ECONOMY_DB_POOL_SIZE/ECONOMY_DB_MAX_OVERFLOW")
        if self.ECONOMY_MAX_REPLICAS * (self.ECONOMY_DB_POOL_SIZE + self.ECONOMY_DB_MAX_OVERFLOW) > self.DB_ECONOMY_CONNECTION_BUDGET:
            unsafe.append("DB_ECONOMY_CONNECTION_BUDGET")
        if unsafe:
            raise RuntimeError("Unsafe Economy service production configuration: " + ", ".join(unsafe))

    def validate_game_platform_service(self) -> None:
        """Validate isolated Game Platform service production settings."""
        if not self.is_production:
            return
        unsafe: list[str] = []
        if not self.GAME_PLATFORM_SERVICE_URL.strip():
            unsafe.append("GAME_PLATFORM_SERVICE_URL")
        url = self.GAME_PLATFORM_DATABASE_URL.strip()
        if not url:
            unsafe.append("GAME_PLATFORM_DATABASE_URL")
        elif url == self.database_url.strip():
            unsafe.append("GAME_PLATFORM_DATABASE_URL(service-isolated credentials required)")
        if self.GAME_PLATFORM_DB_POOL_SIZE <= 0 or self.GAME_PLATFORM_DB_MAX_OVERFLOW < 0:
            unsafe.append("GAME_PLATFORM_DB_POOL_SIZE/GAME_PLATFORM_DB_MAX_OVERFLOW")
        if self.GAME_PLATFORM_MAX_REPLICAS * (self.GAME_PLATFORM_DB_POOL_SIZE + self.GAME_PLATFORM_DB_MAX_OVERFLOW) > self.DB_GAME_PLATFORM_CONNECTION_BUDGET:
            unsafe.append("DB_GAME_PLATFORM_CONNECTION_BUDGET")
        if unsafe:
            raise RuntimeError("Unsafe Game Platform production configuration: " + ", ".join(unsafe))

    def validate_economy_bulk_worker(self) -> None:
        """Validate durable Economy bulk-grant worker capacity."""
        if self.ECONOMY_BULK_BATCH_SIZE < 50 or self.ECONOMY_BULK_BATCH_SIZE > 5000:
            raise RuntimeError("Unsafe ECONOMY_BULK_BATCH_SIZE")
        if self.ECONOMY_BULK_LEASE_SECONDS < 30:
            raise RuntimeError("Unsafe ECONOMY_BULK_LEASE_SECONDS")
        if self.ECONOMY_BULK_POLL_SECONDS < 0.1:
            raise RuntimeError("Unsafe ECONOMY_BULK_POLL_SECONDS")
        if (
            self.ECONOMY_BULK_WORKER_MAX_REPLICAS
            * (
                self.ECONOMY_BULK_WORKER_DB_POOL_SIZE
                + self.ECONOMY_BULK_WORKER_DB_MAX_OVERFLOW
            )
            > self.DB_ECONOMY_BULK_WORKER_CONNECTION_BUDGET
        ):
            raise RuntimeError(
                "Unsafe DB_ECONOMY_BULK_WORKER_CONNECTION_BUDGET"
            )
        if self.is_production:
            url = self.ECONOMY_DATABASE_URL.strip()
            if not url or url == self.database_url.strip():
                raise RuntimeError(
                    "Unsafe Economy bulk worker database credentials"
                )

    def validate_worker_runtime(self) -> None:
        """Reject worker-only service credentials that are unsafe in production."""

        if not self.is_production:
            return
        unsafe: list[str] = []
        if (
            len(self.VIBES_INTERNAL_TOKEN.strip()) < 32
            or "change-this" in self.VIBES_INTERNAL_TOKEN.lower()
        ):
            unsafe.append("VIBES_INTERNAL_TOKEN")
        if unsafe:
            raise RuntimeError(
                "Unsafe worker runtime configuration: " + ", ".join(unsafe)
            )

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )


settings = Settings()
