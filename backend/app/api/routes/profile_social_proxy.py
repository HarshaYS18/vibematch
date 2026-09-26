from __future__ import annotations
import asyncio
import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response
from app.core.config import settings

router = APIRouter(tags=["Profile Social Service Proxy"])
_HEADERS = {"authorization","content-type","accept","idempotency-key","traceparent","tracestate","x-request-id"}

async def _proxy(request: Request, relative_path: str) -> Response:
    body = await request.body()
    headers = {k:v for k,v in request.headers.items() if k.lower() in _HEADERS}
    def execute() -> requests.Response:
        return requests.request(
            request.method,
            settings.PROFILE_SOCIAL_SERVICE_URL.rstrip("/") + "/" + relative_path.lstrip("/"),
            params=list(request.query_params.multi_items()), headers=headers, data=body or None,
            timeout=settings.PROFILE_SOCIAL_SERVICE_TIMEOUT_SECONDS, allow_redirects=False,
        )
    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(content=b'{"detail":"Profile/Social service unavailable"}', status_code=503, media_type="application/json")
    return Response(content=upstream.content, status_code=upstream.status_code, headers={
        k:v for k,v in upstream.headers.items() if k.lower() in {"content-type","cache-control","etag","last-modified","x-request-id"}
    })

async def _proxy_profile_me(request: Request) -> Response:
    return await _proxy(request, "profile-display/me")


async def _proxy_profile_user(request: Request, public_user_id: int) -> Response:
    return await _proxy(request, f"profile-display/users/{public_user_id}")


async def _proxy_family_members(request: Request, family_id: str) -> Response:
    return await _proxy(request, f"families/{family_id}/members")


router.add_api_route(
    "/profile-display/me",
    _proxy_profile_me,
    methods=["GET"],
    name="profile_display_me_proxy",
)
router.add_api_route(
    "/profile-display/users/{public_user_id}",
    _proxy_profile_user,
    methods=["GET"],
    name="profile_display_user_proxy",
)
router.add_api_route(
    "/families/{family_id}/members",
    _proxy_family_members,
    methods=["GET"],
    name="family_members_proxy",
)


for _prefix in ("social", "love-bonds", "families", "profile-display"):
    async def _root(request: Request, prefix: str = _prefix) -> Response:
        return await _proxy(request, prefix)
    async def _child(request: Request, path: str, prefix: str = _prefix) -> Response:
        return await _proxy(request, f"{prefix}/{path}")
    router.add_api_route(f"/{_prefix}", _root, methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
    router.add_api_route(f"/{_prefix}/{{path:path}}", _child, methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
