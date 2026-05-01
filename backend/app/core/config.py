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
    FOUNDER_OWNER_EMAIL: str = "founder@vibematch.com"

    # Local laptop CDN / media settings.
    # Keep MEDIA_PUBLIC_BASE_URL empty for same-host URLs like /media/avatars/...
    # Set it later to a LAN, tunnel, or cloud CDN URL without changing stored keys.
    MEDIA_STORAGE_BACKEND: str = "local"
    MEDIA_ROOT_DIR: str = "storage/media"
    MEDIA_PUBLIC_PATH: str = "/media"
    MEDIA_PUBLIC_BASE_URL: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )


settings = Settings()
