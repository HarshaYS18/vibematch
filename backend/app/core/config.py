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

    # WebRTC / mediasoup audio tokens.
    # Keep this identical to services/mediasoup-audio-server/.env AUDIO_JWT_SECRET_KEY.
    # If omitted, the normal app JWT secret is reused for local testing.
    AUDIO_JWT_SECRET_KEY: str | None = None
    AUDIO_JWT_ALGORITHM: str | None = None
    AUDIO_SESSION_EXPIRE_MINUTES: int = 10

    # Founder Owner
    FOUNDER_OWNER_PUBLIC_ID: int = 6922022

    @property
    def audio_jwt_secret_key(self) -> str:
        return self.AUDIO_JWT_SECRET_KEY or self.JWT_SECRET_KEY

    @property
    def audio_jwt_algorithm(self) -> str:
        return self.AUDIO_JWT_ALGORITHM or self.JWT_ALGORITHM

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )


settings = Settings()
