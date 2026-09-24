from __future__ import annotations
import asyncio
import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response
from app.core.config import settings

router = APIRouter(tags=["Identity Service Proxy"])
_HEADERS = {"authorization","content-type","accept","idempotency-key","traceparent","tracestate","x-request-id"}

async def _proxy(request: Request, relative_path: str) -> Response:
    body = await request.body()
    headers = {k:v for k,v in request.headers.items() if k.lower() in _HEADERS}
    def execute() -> requests.Response:
        return requests.request(
            request.method,
            settings.IDENTITY_SERVICE_URL.rstrip("/") + "/" + relative_path.lstrip("/"),
            params=list(request.query_params.multi_items()), headers=headers, data=body or None,
            timeout=settings.IDENTITY_SERVICE_TIMEOUT_SECONDS, allow_redirects=False,
        )
    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(content=b'{"detail":"Identity service unavailable"}', status_code=503, media_type="application/json")
    return Response(content=upstream.content, status_code=upstream.status_code, headers={
        k:v for k,v in upstream.headers.items() if k.lower() in {"content-type","cache-control","etag","last-modified","x-request-id"}
    })

@router.api_route("/auth/{path:path}", methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
async def proxy_auth(request: Request, path: str) -> Response:
    return await _proxy(request, f"auth/{path}")
