from __future__ import annotations

import asyncio

import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response

from app.core.config import settings


router = APIRouter(tags=["Economy Service Proxy"])

_FORWARD_REQUEST_HEADERS = {
    "authorization",
    "content-type",
    "accept",
    "idempotency-key",
    "traceparent",
    "tracestate",
    "x-request-id",
}
_FORWARD_RESPONSE_HEADERS = {
    "content-type",
    "cache-control",
    "etag",
    "last-modified",
    "x-request-id",
}


async def _proxy(request: Request, relative_path: str) -> Response:
    body = await request.body()
    headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() in _FORWARD_REQUEST_HEADERS
    }
    url = settings.ECONOMY_SERVICE_URL.rstrip("/") + "/" + relative_path.lstrip("/")

    def execute() -> requests.Response:
        return requests.request(
            method=request.method,
            url=url,
            params=list(request.query_params.multi_items()),
            headers=headers,
            data=body or None,
            timeout=settings.ECONOMY_SERVICE_TIMEOUT_SECONDS,
            allow_redirects=False,
        )

    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(
            content=b'{"detail":"Economy service unavailable"}',
            status_code=503,
            media_type="application/json",
        )

    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        headers={
            key: value
            for key, value in upstream.headers.items()
            if key.lower() in _FORWARD_RESPONSE_HEADERS
        },
    )


def _register_prefix(prefix: str) -> None:
    async def root(request: Request) -> Response:
        return await _proxy(request, prefix)

    async def child(request: Request, path: str) -> Response:
        return await _proxy(request, f"{prefix}/{path}")

    router.add_api_route(
        f"/{prefix}",
        root,
        methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    )
    router.add_api_route(
        f"/{prefix}/{{path:path}}",
        child,
        methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    )


for _prefix in (
    "coin-sales",
    "economy/lucky-coins",
    "lucky-packets",
    "gifts",
    "lucky-gifts",
    "admin/games/pools",
    "admin/economy/coin-sales",
    "admin/economy/gifts",
):
    _register_prefix(_prefix)
