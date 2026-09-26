from __future__ import annotations

from typing import Any

import requests

from app.core.config import settings


class IdentityServiceUnavailable(RuntimeError):
    pass


class IdentityServiceAuthError(ValueError):
    def __init__(self, status_code: int, detail: str):
        super().__init__(detail)
        self.status_code = int(status_code)
        self.detail = detail


def verify_access_token(token: str) -> dict[str, Any]:
    url = settings.IDENTITY_INTERNAL_URL.rstrip("/") + "/verify"
    try:
        response = requests.post(
            url,
            headers={
                "X-FunKey-Internal-Token": settings.IDENTITY_INTERNAL_TOKEN,
                "Accept": "application/json",
            },
            json={"token": token},
            timeout=settings.IDENTITY_SERVICE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise IdentityServiceUnavailable("Identity service unavailable") from exc

    if not 200 <= response.status_code < 300:
        detail = "Identity verification failed"
        try:
            decoded = response.json()
            detail = str(decoded.get("detail") or detail)
        except Exception:
            pass
        if response.status_code >= 500:
            raise IdentityServiceUnavailable(detail)
        raise IdentityServiceAuthError(response.status_code, detail)

    decoded = response.json()
    if not isinstance(decoded, dict):
        raise IdentityServiceUnavailable("Identity service returned an invalid response")
    return decoded


def set_special_permission(
    *,
    target_user_id: int,
    actor_user_id: int,
    permission: str,
    enabled: bool,
    reason: str,
) -> dict[str, Any]:
    url = settings.IDENTITY_INTERNAL_URL.rstrip("/") + "/special-permissions/set"
    try:
        response = requests.post(
            url,
            headers={
                "X-FunKey-Internal-Token": settings.IDENTITY_INTERNAL_TOKEN,
                "Accept": "application/json",
            },
            json={
                "target_user_id": int(target_user_id),
                "actor_user_id": int(actor_user_id),
                "permission": permission,
                "enabled": bool(enabled),
                "reason": reason,
            },
            timeout=settings.IDENTITY_SERVICE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise IdentityServiceUnavailable("Identity service unavailable") from exc
    if not 200 <= response.status_code < 300:
        detail = "Identity special-permission update failed"
        try:
            decoded = response.json()
            detail = str(decoded.get("detail") or detail)
        except Exception:
            pass
        if response.status_code >= 500:
            raise IdentityServiceUnavailable(detail)
        raise IdentityServiceAuthError(response.status_code, detail)
    decoded = response.json()
    if not isinstance(decoded, dict):
        raise IdentityServiceUnavailable("Identity service returned an invalid response")
    return decoded
