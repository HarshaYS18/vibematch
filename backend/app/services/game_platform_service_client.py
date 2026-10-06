from __future__ import annotations

from typing import Any

import requests

from app.core.config import settings


class GamePlatformServiceUnavailable(RuntimeError):
    pass


class GamePlatformServiceError(ValueError):
    def __init__(self, status_code: int, detail: str):
        super().__init__(detail)
        self.status_code = int(status_code)
        self.detail = detail


def _request(
    method: str,
    path: str,
    *,
    authorization: str,
    json_body: dict[str, Any] | None = None,
) -> dict[str, Any]:
    url = settings.GAME_PLATFORM_SERVICE_URL.rstrip("/") + "/" + path.lstrip("/")
    try:
        response = requests.request(
            method,
            url,
            headers={
                "Authorization": authorization,
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
            json=json_body,
            timeout=settings.GAME_PLATFORM_SERVICE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise GamePlatformServiceUnavailable("Game Platform service unavailable") from exc
    if not 200 <= response.status_code < 300:
        detail = "Game Platform request failed"
        try:
            decoded = response.json()
            detail = str(decoded.get("detail") or detail)
        except Exception:
            pass
        if response.status_code >= 500:
            raise GamePlatformServiceUnavailable(detail)
        raise GamePlatformServiceError(response.status_code, detail)
    decoded = response.json() if response.content else {}
    if not isinstance(decoded, dict):
        raise GamePlatformServiceUnavailable("Game Platform returned an invalid response")
    return decoded


def create_round(
    *,
    authorization: str,
    game_key: str,
    room_id: int | None,
) -> dict[str, Any]:
    return _request(
        "POST",
        f"games/{game_key}/rounds",
        authorization=authorization,
        json_body={"room_id": room_id},
    )
