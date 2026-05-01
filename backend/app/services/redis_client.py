from __future__ import annotations

from redis import Redis
from redis.exceptions import RedisError

from app.core.config import settings


class RedisClient:
    """Small Redis wrapper for optional local/dev infrastructure.

    If Redis is down, callers can gracefully fall back to in-memory behavior.
    """

    def __init__(self) -> None:
        self._client: Redis | None = None

    @property
    def client(self) -> Redis:
        if self._client is None:
            self._client = Redis.from_url(
                settings.redis_url,
                decode_responses=True,
                socket_connect_timeout=1,
                socket_timeout=1,
            )
        return self._client

    def ping(self) -> bool:
        try:
            return bool(self.client.ping())
        except RedisError:
            return False


redis_client = RedisClient()
