"""Bounded operational telemetry for the Python control plane.

Metrics use route templates rather than user/room identifiers. SQL query counts
are ContextVar-scoped so tests can detect N+1 regressions without production APM.
"""

from contextvars import ContextVar, Token
import json
import logging
import threading
import time
from collections import defaultdict
from uuid import uuid4

from fastapi import Request
from fastapi.responses import JSONResponse
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
_inflight = 0
_buckets = (0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)
_db_query_count: ContextVar[int | None] = ContextVar("funkey_db_query_count", default=None)
_counted_engines: set[int] = set()


def _request_id(request: Request) -> str:
    candidate = request.headers.get("x-request-id", "")
    if 1 <= len(candidate) <= 64 and all(char.isalnum() or char in "-_." for char in candidate):
        return candidate
    return uuid4().hex


def install_query_counter(engine) -> None:
    if id(engine) in _counted_engines:
        return
    event.listen(engine, "before_cursor_execute", _count_query)
    _counted_engines.add(id(engine))


def _count_query(_conn, _cursor, _statement, _parameters, _context, _executemany) -> None:
    current = _db_query_count.get()
    if current is not None:
        _db_query_count.set(current + 1)


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
        payload = {
            "event": "http.request",
            "request_id": request_id,
            "trace_id": current_trace_id(),
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
