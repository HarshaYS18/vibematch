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
    redis_url: str = "redis://localhost:6379/0"
    REDIS_CONNECT_TIMEOUT_SECONDS: float = 2.0
    REDIS_SOCKET_TIMEOUT_SECONDS: float = 2.0

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

    # Topology budgets. These are planning/validation limits, not capacity claims.
    API_MAX_REPLICAS: int = 20
    DB_API_CONNECTION_BUDGET: int = 100
    WORKER_MAX_REPLICAS: int = 20
    DB_WORKER_POOL_SIZE: int = 3
    DB_WORKER_MAX_OVERFLOW: int = 0
    DB_WORKER_CONNECTION_BUDGET: int = 60
    DB_ROLLOUT_SURGE_CONNECTION_RESERVE: int = 20
    DB_POOLER_MAX_CLIENT_CONNECTIONS: int = 400
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
    def expected_pooler_client_connections(self) -> int:
        return (
            self.DB_API_CONNECTION_BUDGET
            + self.DB_WORKER_CONNECTION_BUDGET
            + self.DB_ROLLOUT_SURGE_CONNECTION_RESERVE
        )

    def validate_production(self) -> None:
        """Reject unsafe deploys before the application accepts traffic."""
        if not self.is_production:
            return
        unsafe = []
        for name in ("JWT_SECRET_KEY", "MEDIA_INTERNAL_TOKEN", "INBOX_BACKUP_ENCRYPTION_KEY"):
            value = getattr(self, name).strip()
            if len(value) < 32 or "change-this" in value.lower():
                unsafe.append(name)
        if self.ENABLE_DEV_LOGIN:
            unsafe.append("ENABLE_DEV_LOGIN")
        if self.JWT_ALGORITHM not in {"HS256", "HS384", "HS512"}:
            unsafe.append("JWT_ALGORITHM")

        db_url = urlsplit(self.database_url)
        if not db_url.scheme.startswith("postgresql") or not db_url.hostname:
            unsafe.append("database_url")
        if self.database_url == "postgresql://postgres:postgres@localhost:5432/vibematch":
            unsafe.append("database_url(default)")
        if self.DB_POOLER_MODE not in {"direct", "transaction"}:
            unsafe.append("DB_POOLER_MODE")
        if self.DB_POOLER_MODE == "transaction":
            migration_url = self.MIGRATION_DATABASE_URL.strip()
            if not migration_url or migration_url == self.database_url:
                unsafe.append("MIGRATION_DATABASE_URL")
            else:
                parsed_migration = urlsplit(migration_url)
                if not parsed_migration.scheme.startswith("postgresql") or not parsed_migration.hostname:
                    unsafe.append("MIGRATION_DATABASE_URL")

        redis_url = urlsplit(self.redis_url)
        if redis_url.scheme not in {"redis", "rediss"} or not redis_url.hostname:
            unsafe.append("redis_url")
        if self.redis_url == "redis://localhost:6379/0":
            unsafe.append("redis_url(default)")
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

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )


settings = Settings()
