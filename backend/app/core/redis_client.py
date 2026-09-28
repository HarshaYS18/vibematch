import redis
import redis.asyncio as redis_async

from app.core.config import settings


_BASE_REDIS_OPTIONS = {
    "decode_responses": True,
    "socket_connect_timeout": settings.REDIS_CONNECT_TIMEOUT_SECONDS,
    "socket_timeout": settings.REDIS_SOCKET_TIMEOUT_SECONDS,
    "socket_keepalive": True,
    "health_check_interval": 30,
}


def _sync_client(url: str, *, role: str, max_connections: int):
    return redis.Redis.from_url(
        url,
        client_name=f"funkey-{role}",
        max_connections=max_connections,
        **_BASE_REDIS_OPTIONS,
    )


def _async_client(url: str, *, role: str, max_connections: int):
    return redis_async.Redis.from_url(
        url,
        client_name=f"funkey-{role}",
        max_connections=max_connections,
        **_BASE_REDIS_OPTIONS,
    )


cache_redis_client = _sync_client(
    settings.cache_redis_url,
    role="cache",
    max_connections=settings.CACHE_REDIS_MAX_CONNECTIONS,
)
async_cache_redis_client = _async_client(
    settings.cache_redis_url,
    role="cache",
    max_connections=settings.CACHE_REDIS_MAX_CONNECTIONS,
)

realtime_redis_client = _sync_client(
    settings.realtime_redis_url,
    role="realtime",
    max_connections=settings.REALTIME_REDIS_MAX_CONNECTIONS,
)
async_realtime_redis_client = _async_client(
    settings.realtime_redis_url,
    role="realtime",
    max_connections=settings.REALTIME_REDIS_MAX_CONNECTIONS,
)

media_registry_redis_client = _sync_client(
    settings.media_registry_redis_url,
    role="media-registry",
    max_connections=settings.MEDIA_REGISTRY_REDIS_MAX_CONNECTIONS,
)


def get_redis():
    """Compatibility alias for the application cache/rate-limit Redis."""
    return cache_redis_client


def get_async_redis():
    """Compatibility alias for the async application cache/rate-limit Redis."""
    return async_cache_redis_client


def get_realtime_redis():
    """Synchronous client for ephemeral room/presence/socket coordination."""
    return realtime_redis_client


def get_async_realtime_redis():
    """Async client for ephemeral room/presence/socket coordination."""
    return async_realtime_redis_client


def get_media_registry_redis():
    """Dedicated single-primary HA Redis client for media-node assignment."""
    return media_registry_redis_client
