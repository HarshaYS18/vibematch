"""Distributed, action-specific fixed-window limits shared by API replicas."""

import hashlib
import ipaddress
import time

from fastapi import Request
from fastapi.responses import JSONResponse
from redis.exceptions import RedisError

from app.core.config import settings
from app.core.redis_client import get_async_redis
from app.core.security import decode_access_token


_INCREMENT = """
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end
return {count, redis.call('PTTL', KEYS[1])}
"""


def _client_ip(request: Request) -> str:
    direct = request.client.host if request.client else "unknown"
    try:
        peer = ipaddress.ip_address(direct)
        networks = [ipaddress.ip_network(item.strip(), strict=False) for item in settings.TRUSTED_PROXY_CIDRS.split(",") if item.strip()]
        if any(peer in network for network in networks):
            forwarded = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
            return str(ipaddress.ip_address(forwarded)) if forwarded else direct
    except ValueError:
        pass
    return direct


def _subject(request: Request) -> str | None:
    authorization = request.headers.get("authorization", "")
    if not authorization.startswith("Bearer "):
        return None
    claims = decode_access_token(authorization[7:].strip()) or {}
    subject = claims.get("sub")
    return str(subject) if subject else None


def _policy(path: str, method: str) -> tuple[str, int]:
    if path.startswith("/api/v1/auth/"):
        return "auth", 20
    if path.startswith("/api/v1/realtime/verify"):
        return "realtime-auth", 180
    if path.startswith("/api/v1/media-realtime/") or path.endswith("/media"):
        return "media-auth", 120
    if path.startswith("/api/v1/media/"):
        return "upload", 20
    if any(part in path for part in ("/wallet", "/gifts", "/economy", "/coin-sales")):
        return "value", 60
    if method in {"POST", "PUT", "PATCH", "DELETE"}:
        return "write", 120
    return "read", 600


def _rate_limit_key(*, category: str, identity: str, now: float) -> str:
    bucket = int(now // 60)
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:24]
    return f"funkey:ratelimit:{category}:{digest}:{bucket}"


def _rate_limit_result(result, limit: int) -> tuple[bool, int]:
    count, ttl_ms = result
    return int(count) <= limit, max(1, int(ttl_ms) // 1000 + 1)


def check_rate_limit(redis_client, *, category: str, identity: str, limit: int, now: float | None = None) -> tuple[bool, int]:
    now = time.time() if now is None else now
    key = _rate_limit_key(category=category, identity=identity, now=now)
    return _rate_limit_result(redis_client.eval(_INCREMENT, 1, key, 120000), limit)


async def check_rate_limit_async(redis_client, *, category: str, identity: str, limit: int, now: float | None = None) -> tuple[bool, int]:
    now = time.time() if now is None else now
    key = _rate_limit_key(category=category, identity=identity, now=now)
    return _rate_limit_result(await redis_client.eval(_INCREMENT, 1, key, 120000), limit)


async def rate_limit_middleware(request: Request, call_next):
    path = request.url.path
    if not settings.RATE_LIMIT_ENABLED or path in {"/", "/live", "/ready", "/health", "/metrics"} or path.startswith("/api/v1/internal/"):
        return await call_next(request)
    category, limit = _policy(path, request.method)
    subject = _subject(request)
    identity = f"user:{subject}" if subject else f"ip:{_client_ip(request)}"
    try:
        allowed, retry_after = await check_rate_limit_async(get_async_redis(), category=category, identity=identity, limit=limit)
    except RedisError:
        return JSONResponse(status_code=503, content={"detail": "Rate limit service unavailable"})
    if not allowed:
        return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded"}, headers={"Retry-After": str(retry_after)})
    return await call_next(request)
