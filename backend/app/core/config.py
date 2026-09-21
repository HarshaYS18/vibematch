from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "FunKey"
    APP_ENV: str = "development"
    ENFORCE_SCHEMA_CURRENT: bool = True
    CORS_ALLOWED_ORIGINS: str = "*"

    # Database / Redis from .env
    database_url: str = "postgresql://postgres:postgres@localhost:5432/vibematch"
    redis_url: str = "redis://localhost:6379/0"

    # Media control plane / node registry
    MEDIA_INTERNAL_TOKEN: str = "change-this-media-internal-token"
    MEDIA_NODE_TTL_SECONDS: int = 30
    MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS: int = 86400

    # JWT
    JWT_SECRET_KEY: str = "change-this-secret-key-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Founder Owner
    FOUNDER_OWNER_PUBLIC_ID: int = 6922022

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
        return self.APP_ENV.strip().lower() in {"production", "prod"}

    def validate_runtime_settings(self) -> None:
        """Fail closed when production is configured with development defaults."""
        if not self.is_production:
            return

        problems: list[str] = []
        if self.JWT_SECRET_KEY.startswith("change-this") or len(self.JWT_SECRET_KEY) < 32:
            problems.append("JWT_SECRET_KEY must be a strong production secret")
        if self.MEDIA_INTERNAL_TOKEN.startswith("change-this") or len(self.MEDIA_INTERNAL_TOKEN) < 32:
            problems.append("MEDIA_INTERNAL_TOKEN must be a strong shared secret")
        if self.cors_allowed_origins == ["*"]:
            problems.append("CORS_ALLOWED_ORIGINS must list explicit production origins")
        if self.ENABLE_DEV_LOGIN:
            problems.append("ENABLE_DEV_LOGIN must be false in production")
        if self.MEDIA_STORAGE_DRIVER.strip().lower() == "local":
            problems.append("MEDIA_STORAGE_DRIVER cannot be local in production")
        if not self.MEDIA_CDN_BASE_URL.strip():
            problems.append("MEDIA_CDN_BASE_URL is required in production")
        if self.MEDIA_STORAGE_DRIVER.strip().lower() == "s3":
            required_s3 = {
                "MEDIA_S3_BUCKET": self.MEDIA_S3_BUCKET,
                "MEDIA_S3_ACCESS_KEY_ID": self.MEDIA_S3_ACCESS_KEY_ID,
                "MEDIA_S3_SECRET_ACCESS_KEY": self.MEDIA_S3_SECRET_ACCESS_KEY,
            }
            missing = [name for name, value in required_s3.items() if not value.strip()]
            if missing:
                problems.append("missing S3 settings: " + ", ".join(missing))

        if problems:
            raise RuntimeError("Unsafe production configuration: " + "; ".join(problems))

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )


settings = Settings()
