import redis
import redis.asyncio as redis_async

from app.core.config import settings


_REDIS_OPTIONS = {
    "decode_responses": True,
    "socket_connect_timeout": settings.REDIS_CONNECT_TIMEOUT_SECONDS,
    "socket_timeout": settings.REDIS_SOCKET_TIMEOUT_SECONDS,
    "socket_keepalive": True,
    "health_check_interval": 30,
}

redis_client = redis.Redis.from_url(settings.redis_url, **_REDIS_OPTIONS)
async_redis_client = redis_async.Redis.from_url(settings.redis_url, **_REDIS_OPTIONS)


def get_redis():
    """Synchronous Redis client for synchronous routes/services."""
    return redis_client


def get_async_redis():
    """Async Redis client for event-loop request paths such as middleware."""
    return async_redis_client
