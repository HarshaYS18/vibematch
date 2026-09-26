from __future__ import annotations

import asyncio

import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response

from app.core.config import settings


router = APIRouter(tags=["Vibes Service Proxy"])
admin_router = APIRouter(tags=["Admin Vibes Service Proxy"])

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


def _target(relative_path: str) -> str:
    return settings.VIBES_SERVICE_URL.rstrip("/") + "/" + relative_path.lstrip("/")


async def _proxy(request: Request, relative_path: str) -> Response:
    body = await request.body()
    headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() in _FORWARD_REQUEST_HEADERS
    }

    def execute() -> requests.Response:
        return requests.request(
            method=request.method,
            url=_target(relative_path),
            params=list(request.query_params.multi_items()),
            headers=headers,
            data=body or None,
            timeout=settings.VIBES_SERVICE_TIMEOUT_SECONDS,
            allow_redirects=False,
        )

    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(
            content=b'{"detail":"Vibes service unavailable"}',
            status_code=503,
            media_type="application/json",
        )

    response_headers = {
        key: value
        for key, value in upstream.headers.items()
        if key.lower() in _FORWARD_RESPONSE_HEADERS
    }
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        headers=response_headers,
    )


@router.get("/vibes/feed")
async def proxy_vibes_feed(request: Request) -> Response:
    return await _proxy(request, "vibes/feed")


@router.api_route(
    "/vibes",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_vibes_root(request: Request) -> Response:
    return await _proxy(request, "vibes")


@router.api_route(
    "/vibes/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_vibes(request: Request, path: str) -> Response:
    return await _proxy(request, f"vibes/{path}")


@admin_router.api_route(
    "/admin/moderation/vibes",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_admin_vibes_root(request: Request) -> Response:
    return await _proxy(request, "admin/moderation/vibes")


@admin_router.api_route(
    "/admin/moderation/vibes/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_admin_vibes(request: Request, path: str) -> Response:
    return await _proxy(request, f"admin/moderation/vibes/{path}")
