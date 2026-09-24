from __future__ import annotations

from typing import Any

import requests

from app.core.config import settings


class RoomControlServiceUnavailable(RuntimeError):
    pass


class RoomControlServiceError(ValueError):
    def __init__(self, status_code: int, detail: str):
        super().__init__(detail)
        self.status_code = int(status_code)
        self.detail = detail


def _request(
    method: str,
    path: str,
    *,
    json_body: dict[str, Any] | None = None,
    params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    url = settings.ROOM_CONTROL_INTERNAL_URL.rstrip("/") + "/" + path.lstrip("/")
    try:
        response = requests.request(
            method,
            url,
            headers={
                "X-FunKey-Internal-Token": settings.ROOM_CONTROL_INTERNAL_TOKEN,
                "Accept": "application/json",
            },
            json=json_body,
            params=params,
            timeout=settings.ROOM_CONTROL_SERVICE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise RoomControlServiceUnavailable("Room Control service unavailable") from exc

    if response.status_code < 200 or response.status_code >= 300:
        detail = "Room Control service request failed"
        try:
            decoded = response.json()
            detail = str(decoded.get("detail") or detail)
        except Exception:
            pass
        if response.status_code >= 500:
            raise RoomControlServiceUnavailable(detail)
        raise RoomControlServiceError(response.status_code, detail)

    if not response.content:
        return {}
    decoded = response.json()
    return decoded if isinstance(decoded, dict) else {}


def resolve_room(room_public_id: str) -> dict[str, Any]:
    return _request("GET", f"rooms/{room_public_id}")


def room_theme_quote(*, user_id: int, theme_id: str) -> dict[str, Any]:
    return _request(
        "GET",
        f"themes/{theme_id}/quote",
        params={"user_id": int(user_id)},
    )


def grant_room_theme(
    *,
    user_id: int,
    theme_id: str,
    source: str,
) -> dict[str, Any]:
    return _request(
        "POST",
        f"themes/{theme_id}/grant",
        json_body={"user_id": int(user_id), "source": source},
    )
