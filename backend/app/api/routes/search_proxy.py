"""Compatibility facade for the separately deployed Search projection service."""

from __future__ import annotations

import asyncio

import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response

from app.core.config import settings

router = APIRouter(tags=["Search Service Proxy"])
_HEADERS = {"authorization", "accept", "traceparent", "tracestate", "x-request-id"}


async def _proxy(request: Request) -> Response:
    headers = {k: v for k, v in request.headers.items() if k.lower() in _HEADERS}

    def execute():
        return requests.get(
            settings.SEARCH_SERVICE_URL.rstrip("/") + "/search",
            params=list(request.query_params.multi_items()),
            headers=headers,
            timeout=settings.SEARCH_SERVICE_TIMEOUT_SECONDS,
            allow_redirects=False,
        )

    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(
            content=b'{"detail":"Search projection unavailable"}',
            status_code=503,
            media_type="application/json",
        )
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        headers={
            k: v
            for k, v in upstream.headers.items()
            if k.lower() in {"content-type", "cache-control", "etag", "x-request-id"}
        },
    )


router.add_api_route("/search", _proxy, methods=["GET", "OPTIONS"])
