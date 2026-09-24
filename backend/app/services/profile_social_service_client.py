from __future__ import annotations
from typing import Any
import requests
from app.core.config import settings

class ProfileSocialServiceUnavailable(RuntimeError):
    pass

class ProfileSocialServiceError(ValueError):
    def __init__(self, status_code: int, detail: str):
        super().__init__(detail)
        self.status_code = int(status_code)
        self.detail = detail

def _request(method: str, path: str, *, json_body: dict[str, Any] | None = None) -> dict[str, Any]:
    url = settings.PROFILE_SOCIAL_INTERNAL_URL.rstrip("/") + "/" + path.lstrip("/")
    try:
        response = requests.request(
            method, url,
            headers={"X-FunKey-Internal-Token": settings.PROFILE_SOCIAL_INTERNAL_TOKEN, "Accept": "application/json"},
            json=json_body,
            timeout=settings.PROFILE_SOCIAL_SERVICE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise ProfileSocialServiceUnavailable("Profile/Social service unavailable") from exc
    if not 200 <= response.status_code < 300:
        detail = "Profile/Social service request failed"
        try:
            detail = str(response.json().get("detail") or detail)
        except Exception:
            pass
        if response.status_code >= 500:
            raise ProfileSocialServiceUnavailable(detail)
        raise ProfileSocialServiceError(response.status_code, detail)
    decoded = response.json() if response.content else {}
    return decoded if isinstance(decoded, dict) else {}

def update_profile(*, user_id: int, profile: dict[str, Any]) -> dict[str, Any]:
    return _request("PATCH", f"users/{int(user_id)}/profile", json_body={"profile": dict(profile)})

def record_profile_visit(*, profile_owner_user_id: int, visitor_user_id: int, source: str) -> dict[str, Any]:
    return _request("POST", "profile-visits", json_body={
        "profile_owner_user_id": int(profile_owner_user_id),
        "visitor_user_id": int(visitor_user_id),
        "source": source,
    })


def assign_custom_id(*, user_id: int, display_custom_id: int | None) -> dict[str, Any]:
    return _request(
        "POST",
        f"admin/users/{int(user_id)}/custom-id",
        json_body={"display_custom_id": display_custom_id},
    )


def set_stealth(
    *,
    user_id: int,
    enabled: bool,
    actor_user_id: int,
    reason: str,
) -> dict[str, Any]:
    return _request(
        "POST",
        f"admin/users/{int(user_id)}/stealth",
        json_body={
            "enabled": bool(enabled),
            "actor_user_id": int(actor_user_id),
            "reason": reason,
        },
    )
