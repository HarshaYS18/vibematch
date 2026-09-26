"""Bounded reconstructable-cache helpers with stampede protection."""

from __future__ import annotations

import asyncio
import hashlib
import json
import random
from dataclasses import dataclass
from typing import Awaitable, Callable, TypeVar

from app.core.redis_client import get_async_redis

T = TypeVar("T")


@dataclass(frozen=True)
class CacheSpec:
    namespace: str
    ttl_seconds: int
    stale_seconds: int


SPECS = {
    "public_profile": CacheSpec("public_profile", 60, 300),
    "home_banners": CacheSpec("home_banners", 30, 120),
    "room_preview": CacheSpec("room_preview", 15, 30),
    "catalog": CacheSpec("catalog", 300, 900),
}


def cache_key(spec: CacheSpec, *parts: object) -> str:
    """Hash identifiers so user/entity values do not become Redis key labels."""
    raw = "\x1f".join(str(part) for part in parts).encode()
    digest = hashlib.sha256(raw).hexdigest()
    return f"funkey:cache:v1:{spec.namespace}:{digest}"


async def cached_json(
    spec: CacheSpec,
    parts: tuple[object, ...],
    loader: Callable[[], Awaitable[T]],
) -> T:
    """Cache one reconstructable JSON value with bounded distributed single-flight."""
    redis = get_async_redis()
    key = cache_key(spec, *parts)
    lock_key = f"{key}:lock"

    raw = await redis.get(key)
    if raw:
        return json.loads(raw)

    token = hashlib.sha256(f"{random.random()}:{key}".encode()).hexdigest()
    acquired = await redis.set(lock_key, token, ex=5, nx=True)
    if acquired:
        try:
            value = await loader()
            jitter = random.uniform(0.9, 1.1)
            ttl = max(1, int(spec.ttl_seconds * jitter))
            await redis.set(key, json.dumps(value, separators=(",", ":")), ex=ttl)
            return value
        finally:
            await redis.eval(
                """
                if redis.call('get', KEYS[1]) == ARGV[1] then
                  return redis.call('del', KEYS[1])
                end
                return 0
                """,
                1,
                lock_key,
                token,
            )

    deadline = asyncio.get_running_loop().time() + 0.5
    delay = 0.025
    while asyncio.get_running_loop().time() < deadline:
        await asyncio.sleep(delay)
        raw = await redis.get(key)
        if raw:
            return json.loads(raw)
        delay = min(delay * 2, 0.1)

    return await loader()
