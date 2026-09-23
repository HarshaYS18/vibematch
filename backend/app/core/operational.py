"""Bounded operational telemetry for the Python control plane.

Metrics use route templates rather than user/room identifiers. SQL query counts
are ContextVar-scoped so tests can detect N+1 regressions without production APM.
"""

from contextvars import ContextVar, Token
import hashlib
import json
import logging
import threading
import time
from collections import defaultdict
from uuid import uuid4

from fastapi import Request
from fastapi.responses import JSONResponse
from opentelemetry import trace
from sqlalchemy import event

from app.core.config import settings
from app.core.telemetry import current_trace_id


_logger = logging.getLogger("funkey.api")
_lock = threading.Lock()
_requests: dict[tuple[str, str, int], int] = defaultdict(int)
_latency: dict[tuple[str, str, str], int] = defaultdict(int)
_latency_count: dict[tuple[str, str], int] = defaultdict(int)
_latency_sum: dict[tuple[str, str], float] = defaultdict(float)
_db_query_sum: dict[tuple[str, str], int] = defaultdict(int)
_db_slow_queries_total = 0
_inflight = 0
_buckets = (0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)
_db_query_count: ContextVar[int | None] = ContextVar("funkey_db_query_count", default=None)
_counted_engines: set[int] = set()


def standard_flow_name(method: str, path: str) -> str | None:
    """Map stable route templates to low-cardinality product flow spans."""
    method = method.upper()
    path = path.lower()

    if method == "POST" and path in {
        "/api/v1/auth/dev-login",
        "/api/v1/auth/google-login",
    }:
        return "auth.login"
    if method == "GET" and (
        path.startswith("/api/v1/home-banners")
        or path in {
            "/api/v1/rooms/trending",
            "/api/v1/rooms/following",
            "/api/v1/rooms/quick-match",
        }
    ):
        return "home.load"
    if method == "POST" and path.endswith("/realtime/join"):
        return "room.join"
    if method == "POST" and "/realtime/seat/" in path:
        return "room.seat.change"
    if method == "POST" and path == "/api/v1/economy/gifts/send":
        return "gift.send"
    if (
        method == "POST"
        and "/api/v1/inbox/conversations/" in path
        and path.endswith("/messages")
    ):
        return "inbox.send"
    if method == "GET" and path.startswith("/api/v1/vibes"):
        return "vibes.load"
    if method == "POST" and path.endswith("/realtime/watch-party/command"):
        return "watch_party.command"
    if method == "POST" and path.startswith("/api/v1/games/") and path.endswith("/rounds"):
        return "game.start"
    if method == "POST" and path.startswith("/api/v1/media/"):
        return "media.upload"
    if method in {"POST", "PATCH", "DELETE"} and path.startswith("/api/v1/wallets/"):
        return "wallet.mutate"
    return None


def _request_id(request: Request) -> str:
    candidate = request.headers.get("x-request-id", "")
    if 1 <= len(candidate) <= 64 and all(char.isalnum() or char in "-_." for char in candidate):
        return candidate
    return uuid4().hex


def install_query_counter(engine) -> None:
    if id(engine) in _counted_engines:
        return
    event.listen(engine, "before_cursor_execute", _count_query)
    event.listen(engine, "after_cursor_execute", _observe_query_duration)
    _counted_engines.add(id(engine))


def _count_query(_conn, _cursor, _statement, _parameters, context, _executemany) -> None:
    current = _db_query_count.get()
    if current is not None:
        _db_query_count.set(current + 1)
    context._funkey_query_started_at = time.monotonic()


def statement_fingerprint(statement: str) -> str:
    """Return a non-reversible identifier without logging SQL or parameters."""
    return hashlib.sha256(statement.encode("utf-8", errors="replace")).hexdigest()[:16]


def _observe_query_duration(_conn, _cursor, statement, _parameters, context, _executemany) -> None:
    global _db_slow_queries_total
    started = getattr(context, "_funkey_query_started_at", None)
    if started is None:
        return
    duration_ms = (time.monotonic() - started) * 1000.0
    if duration_ms < settings.DB_SLOW_QUERY_MS:
        return

    operation = statement.lstrip().split(None, 1)[0].upper() if statement.strip() else "UNKNOWN"
    with _lock:
        _db_slow_queries_total += 1

    active_span = trace.get_current_span()
    if active_span.is_recording():
        active_span.set_attribute("funkey.db.slow_query", True)
        active_span.set_attribute("db.operation.name", operation)
        active_span.set_attribute("funkey.db.statement_fingerprint", statement_fingerprint(statement))

    _logger.warning(json.dumps({
        "event": "db.slow_query",
        "trace_id": current_trace_id(),
        "duration_ms": round(duration_ms, 2),
        "operation": operation,
        "statement_fingerprint": statement_fingerprint(statement),
    }, separators=(",", ":")))


def begin_query_count() -> Token:
    return _db_query_count.set(0)


def current_query_count() -> int:
    return _db_query_count.get() or 0


def end_query_count(token: Token) -> None:
    _db_query_count.reset(token)


async def operational_middleware(request: Request, call_next):
    global _inflight
    request_id = _request_id(request)
    request.state.request_id = request_id
    query_token = begin_query_count()
    started = time.monotonic()
    with _lock:
        _inflight += 1
    try:
        length = request.headers.get("content-length")
        if length and (not length.isdigit() or int(length) > settings.MAX_REQUEST_BYTES):
            response = JSONResponse(status_code=413, content={"detail": "Request body too large"})
        else:
            response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["X-Frame-Options"] = "DENY"
        if settings.DB_QUERY_COUNT_RESPONSE_HEADER and not settings.is_production:
            response.headers["X-FunKey-DB-Query-Count"] = str(current_query_count())
        if settings.is_production:
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response
    finally:
        elapsed = time.monotonic() - started
        query_count = current_query_count()
        route = request.scope.get("route")
        path = getattr(route, "path", "unmatched")
        method = request.method
        status = getattr(locals().get("response"), "status_code", 500)
        with _lock:
            _inflight -= 1
            _requests[(method, path, status)] += 1
            _latency_count[(method, path)] += 1
            _latency_sum[(method, path)] += elapsed
            _db_query_sum[(method, path)] += query_count
            for bucket in _buckets:
                if elapsed <= bucket:
                    _latency[(method, path, str(bucket))] += 1
            _latency[(method, path, "+Inf")] += 1
        flow = standard_flow_name(method, path)
        active_span = trace.get_current_span()
        if flow and active_span.is_recording():
            active_span.update_name(flow)
            active_span.set_attribute("funkey.flow", flow)
        payload = {
            "event": "http.request",
            "request_id": request_id,
            "trace_id": current_trace_id(),
            "flow": flow,
            "method": method,
            "route": path,
            "status": status,
            "duration_ms": round(elapsed * 1000, 2),
            "db_query_count": query_count,
        }
        _logger.info(json.dumps(payload, separators=(",", ":")))
        end_query_count(query_token)


def render_metrics(pool=None) -> str:
    with _lock:
        requests = dict(_requests)
        latency = dict(_latency)
        latency_count = dict(_latency_count)
        latency_sum = dict(_latency_sum)
        db_query_sum = dict(_db_query_sum)
        db_slow_queries_total = _db_slow_queries_total
        inflight = _inflight
    lines = [
        "# TYPE funkey_http_inflight_requests gauge",
        f"funkey_http_inflight_requests {inflight}",
        "# TYPE funkey_http_requests_total counter",
    ]
    for (method, path, status), count in sorted(requests.items()):
        lines.append(
            f'funkey_http_requests_total{{method={json.dumps(method)},route={json.dumps(path)},status="{status}"}} {count}'
        )
    lines.append("# TYPE funkey_http_request_duration_seconds histogram")
    for (method, path, bucket), count in sorted(latency.items()):
        lines.append(
            f'funkey_http_request_duration_seconds_bucket{{method={json.dumps(method)},route={json.dumps(path)},le="{bucket}"}} {count}'
        )
    for (method, path), count in sorted(latency_count.items()):
        lines.append(
            f'funkey_http_request_duration_seconds_count{{method={json.dumps(method)},route={json.dumps(path)}}} {count}'
        )
        lines.append(
            f'funkey_http_request_duration_seconds_sum{{method={json.dumps(method)},route={json.dumps(path)}}} {latency_sum[(method, path)]:.9f}'
        )
    lines.append("# TYPE funkey_http_db_queries_total counter")
    for (method, path), count in sorted(db_query_sum.items()):
        lines.append(
            f'funkey_http_db_queries_total{{method={json.dumps(method)},route={json.dumps(path)}}} {count}'
        )
    lines.extend([
        "# TYPE funkey_db_slow_queries_total counter",
        f"funkey_db_slow_queries_total {db_slow_queries_total}",
    ])
    if pool is not None and hasattr(pool, "checkedout"):
        lines.extend([
            "# TYPE funkey_db_pool_checked_out gauge",
            f"funkey_db_pool_checked_out {pool.checkedout()}",
            "# TYPE funkey_db_pool_size gauge",
            f"funkey_db_pool_size {pool.size()}",
            "# TYPE funkey_db_pool_overflow gauge",
            f"funkey_db_pool_overflow {pool.overflow()}",
        ])
    return "\n".join(lines) + "\n"
