"""Small, bounded operational telemetry for the Python control plane.

Metrics are per replica and intentionally use route templates, never raw URLs,
user IDs or room IDs as labels. A Prometheus scraper aggregates replicas.
"""

import json
import logging
import threading
import time
from collections import defaultdict
from uuid import uuid4

from fastapi import Request
from fastapi.responses import JSONResponse

from app.core.config import settings


_logger = logging.getLogger("funkey.api")
_lock = threading.Lock()
_requests: dict[tuple[str, str, int], int] = defaultdict(int)
_latency: dict[tuple[str, str, str], int] = defaultdict(int)
_inflight = 0
_buckets = (0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)


def _request_id(request: Request) -> str:
    candidate = request.headers.get("x-request-id", "")
    if 1 <= len(candidate) <= 64 and all(char.isalnum() or char in "-_." for char in candidate):
        return candidate
    return uuid4().hex


async def operational_middleware(request: Request, call_next):
    global _inflight
    request_id = _request_id(request)
    request.state.request_id = request_id
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
        if settings.is_production:
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response
    finally:
        elapsed = time.monotonic() - started
        route = request.scope.get("route")
        path = getattr(route, "path", "unmatched")
        method = request.method
        status = getattr(locals().get("response"), "status_code", 500)
        with _lock:
            _inflight -= 1
            _requests[(method, path, status)] += 1
            for bucket in _buckets:
                if elapsed <= bucket:
                    _latency[(method, path, str(bucket))] += 1
            _latency[(method, path, "+Inf")] += 1
        _logger.info(json.dumps({
            "event": "http.request", "request_id": request_id,
            "method": method, "route": path, "status": status,
            "duration_ms": round(elapsed * 1000, 2),
        }, separators=(",", ":")))


def render_metrics(pool=None) -> str:
    with _lock:
        requests = dict(_requests)
        latency = dict(_latency)
        inflight = _inflight
    lines = [
        "# TYPE funkey_http_inflight_requests gauge",
        f"funkey_http_inflight_requests {inflight}",
        "# TYPE funkey_http_requests_total counter",
    ]
    for (method, path, status), count in sorted(requests.items()):
        lines.append(f'funkey_http_requests_total{{method={json.dumps(method)},route={json.dumps(path)},status="{status}"}} {count}')
    lines.append("# TYPE funkey_http_request_duration_seconds histogram")
    for (method, path, bucket), count in sorted(latency.items()):
        lines.append(f'funkey_http_request_duration_seconds_bucket{{method={json.dumps(method)},route={json.dumps(path)},le="{bucket}"}} {count}')
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
