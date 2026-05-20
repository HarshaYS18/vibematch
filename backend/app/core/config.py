from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "Vibe Match"

    # Database / Redis from .env
    database_url: str = "postgresql://postgres:postgres@localhost:5432/vibematch"
    redis_url: str = "redis://localhost:6379/0"

    # JWT
    JWT_SECRET_KEY: str = "change-this-secret-key-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Founder Owner
    FOUNDER_OWNER_PUBLIC_ID: int = 6922022

    # Dynamic gift assets. In production set this to your CDN, e.g.
    # https://cdn.funkey.app. When empty, API still returns local bundled
    # fallback paths for closed-beta testing.
    GIFT_CDN_BASE_URL: str = ""

    # Google Sign-In OAuth client IDs. Comma-separated for web/android/ios clients.
    GOOGLE_AUTH_CLIENT_IDS: str = ""
    ENABLE_DEV_LOGIN: bool = False

    # Google Drive backup OAuth
    GOOGLE_DRIVE_CLIENT_ID: str = ""
    GOOGLE_DRIVE_CLIENT_SECRET: str = ""
    GOOGLE_DRIVE_REDIRECT_URI: str = "http://127.0.0.1:8000/inbox/backup/google/callback"
    GOOGLE_DRIVE_SCOPES: str = "https://www.googleapis.com/auth/drive.file"
    INBOX_BACKUP_ENCRYPTION_KEY: str = "change-this-32-byte-key-before-production"

    # Firebase Cloud Messaging HTTP v1
    FCM_PROJECT_ID: str = ""
    FIREBASE_SERVICE_ACCOUNT_PATH: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )


settings = Settings()
