from __future__ import annotations

import asyncio

import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response

from app.core.config import settings


router = APIRouter(tags=["Room Control Service Proxy"])
admin_router = APIRouter(tags=["Admin Room Control Service Proxy"])

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
    return settings.ROOM_CONTROL_SERVICE_URL.rstrip("/") + "/" + relative_path.lstrip("/")


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
            timeout=settings.ROOM_CONTROL_SERVICE_TIMEOUT_SECONDS,
            allow_redirects=False,
        )

    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(
            content=b'{"detail":"Room Control service unavailable"}',
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


@router.get("/rooms/trending")
async def proxy_room_trending(request: Request) -> Response:
    return await _proxy(request, "rooms/trending")


@router.get("/rooms/{room_public_id}/realtime/snapshot")
async def proxy_room_realtime_snapshot(
    request: Request,
    room_public_id: str,
) -> Response:
    return await _proxy(
        request,
        f"rooms/{room_public_id}/realtime/snapshot",
    )


@router.api_route(
    "/rooms",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_rooms_root(request: Request) -> Response:
    return await _proxy(request, "rooms")


@router.api_route(
    "/rooms/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_rooms(request: Request, path: str) -> Response:
    return await _proxy(request, f"rooms/{path}")


@admin_router.api_route(
    "/admin/rooms",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_admin_rooms_root(request: Request) -> Response:
    return await _proxy(request, "admin/rooms")


@admin_router.api_route(
    "/admin/rooms/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_admin_rooms(request: Request, path: str) -> Response:
    return await _proxy(request, f"admin/rooms/{path}")
