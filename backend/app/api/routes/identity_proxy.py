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


# Exact compatibility routes for Identity-owned privileged account/security APIs.
# We register them explicitly instead of a broad /admin wildcard so unrelated
# economy/media/control-plane admin surfaces remain with their own authorities.

async def _admin_control_summary(request: Request) -> Response:
    return await _proxy(request, "admin/control-summary")

async def _admin_role_options(request: Request) -> Response:
    return await _proxy(request, "admin/role-options")

async def _admin_users(request: Request) -> Response:
    return await _proxy(request, "admin/users")

async def _admin_audit_logs(request: Request) -> Response:
    return await _proxy(request, "admin/audit-logs")

async def _admin_login_history(request: Request) -> Response:
    return await _proxy(request, "admin/login-history")

async def _admin_login_history_user(request: Request, user_id: int) -> Response:
    return await _proxy(request, f"admin/login-history/user/{user_id}")

async def _admin_login_history_device(request: Request, device_id: str) -> Response:
    return await _proxy(request, f"admin/login-history/device/{device_id}")

async def _admin_special_permissions(request: Request) -> Response:
    return await _proxy(request, "admin/users/special-permissions")

async def _admin_special_permissions_grant(request: Request) -> Response:
    return await _proxy(request, "admin/users/special-permissions/grant")

async def _admin_special_permissions_revoke(request: Request) -> Response:
    return await _proxy(request, "admin/users/special-permissions/revoke")

async def _admin_role_assign(request: Request) -> Response:
    return await _proxy(request, "admin/roles/assign")

async def _moderation_user_ban(request: Request) -> Response:
    return await _proxy(request, "admin/moderation/users/ban")

async def _moderation_user_unban(request: Request) -> Response:
    return await _proxy(request, "admin/moderation/users/unban")

async def _moderation_user_bans(request: Request) -> Response:
    return await _proxy(request, "admin/moderation/users/bans")

async def _moderation_device_unban(request: Request) -> Response:
    return await _proxy(request, "admin/moderation/devices/unban")

async def _moderation_device_bans(request: Request) -> Response:
    return await _proxy(request, "admin/moderation/devices/bans")

for path, endpoint, methods in (
    ("/admin/control-summary", _admin_control_summary, ["GET"]),
    ("/admin/role-options", _admin_role_options, ["GET"]),
    ("/admin/users", _admin_users, ["GET"]),
    ("/admin/audit-logs", _admin_audit_logs, ["GET"]),
    ("/admin/login-history", _admin_login_history, ["GET"]),
    ("/admin/login-history/user/{user_id}", _admin_login_history_user, ["GET"]),
    ("/admin/login-history/device/{device_id}", _admin_login_history_device, ["GET"]),
    ("/admin/users/special-permissions", _admin_special_permissions, ["GET"]),
    ("/admin/users/special-permissions/grant", _admin_special_permissions_grant, ["POST"]),
    ("/admin/users/special-permissions/revoke", _admin_special_permissions_revoke, ["POST"]),
    ("/admin/roles/assign", _admin_role_assign, ["POST"]),
    ("/admin/moderation/users/ban", _moderation_user_ban, ["POST"]),
    ("/admin/moderation/users/unban", _moderation_user_unban, ["POST"]),
    ("/admin/moderation/users/bans", _moderation_user_bans, ["GET"]),
    ("/admin/moderation/devices/unban", _moderation_device_unban, ["POST"]),
    ("/admin/moderation/devices/bans", _moderation_device_bans, ["GET"]),
):
    router.add_api_route(path, endpoint, methods=methods)
