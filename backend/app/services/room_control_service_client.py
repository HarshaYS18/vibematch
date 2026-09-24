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


def authorize_room_action(
    *,
    user_id: int,
    room_public_id: str,
    action: str,
    device_id: str | None = None,
    has_active_room_connection: bool = False,
    evaluate_permissions: bool = True,
) -> dict[str, Any]:
    return _request(
        "POST",
        "authorize",
        json_body={
            "user_id": int(user_id),
            "room_public_id": room_public_id,
            "action": action,
            "device_id": device_id,
            "has_active_room_connection": bool(has_active_room_connection),
            "evaluate_permissions": bool(evaluate_permissions),
        },
    )


def execute_realtime_command(
    *,
    user_id: int,
    command_type: str,
    room_public_id: str,
    activity: str | None,
    payload: dict[str, Any] | None,
    command_id: str | None,
) -> dict[str, Any]:
    return _request(
        "POST",
        "command",
        json_body={
            "user_id": int(user_id),
            "command_type": command_type,
            "room_public_id": room_public_id,
            "activity": activity,
            "payload": dict(payload or {}),
            "command_id": command_id,
        },
    )
