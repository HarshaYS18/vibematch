from __future__ import annotations

import asyncio

import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response

from app.core.config import settings


router = APIRouter(tags=["Inbox Service Proxy"])

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
    return settings.INBOX_SERVICE_URL.rstrip("/") + "/" + relative_path.lstrip("/")


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
            timeout=settings.INBOX_SERVICE_TIMEOUT_SECONDS,
            allow_redirects=False,
        )

    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(
            content=b'{"detail":"Inbox service unavailable"}',
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


@router.get("/inbox/conversations")
async def proxy_inbox_conversations(request: Request) -> Response:
    return await _proxy(request, "inbox/conversations")


@router.get("/inbox/lock/status")
async def proxy_inbox_lock_status(request: Request) -> Response:
    return await _proxy(request, "inbox/lock/status")


@router.get("/inbox/backup/status")
async def proxy_inbox_backup_status(request: Request) -> Response:
    return await _proxy(request, "inbox/backup/status")


@router.api_route(
    "/inbox",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_inbox_root(request: Request) -> Response:
    return await _proxy(request, "inbox")


@router.api_route(
    "/inbox/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_inbox(request: Request, path: str) -> Response:
    return await _proxy(request, f"inbox/{path}")


@router.api_route(
    "/inbox-ai",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_inbox_ai_root(request: Request) -> Response:
    return await _proxy(request, "inbox-ai")


@router.api_route(
    "/inbox-ai/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_inbox_ai(request: Request, path: str) -> Response:
    return await _proxy(request, f"inbox-ai/{path}")


@router.api_route(
    "/calls",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_calls_root(request: Request) -> Response:
    return await _proxy(request, "calls")


@router.api_route(
    "/calls/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
async def proxy_calls(request: Request, path: str) -> Response:
    return await _proxy(request, f"calls/{path}")
