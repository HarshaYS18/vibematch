from __future__ import annotations

from typing import Any

import requests

from app.core.config import settings


class InboxServiceUnavailable(RuntimeError):
    pass


def _request(
    method: str,
    path: str,
    *,
    json_body: dict[str, Any] | None = None,
    params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    url = settings.INBOX_INTERNAL_URL.rstrip("/") + "/" + path.lstrip("/")
    try:
        response = requests.request(
            method,
            url,
            headers={
                "X-FunKey-Internal-Token": settings.INBOX_INTERNAL_TOKEN,
                "Accept": "application/json",
            },
            json=json_body,
            params=params,
            timeout=settings.INBOX_SERVICE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise InboxServiceUnavailable("Inbox service unavailable") from exc

    if response.status_code < 200 or response.status_code >= 300:
        detail = "Inbox service request failed"
        try:
            decoded = response.json()
            detail = str(decoded.get("detail") or detail)
        except Exception:
            pass
        if response.status_code >= 500:
            raise InboxServiceUnavailable(detail)
        raise ValueError(detail)

    if not response.content:
        return {}
    decoded = response.json()
    return decoded if isinstance(decoded, dict) else {}


def send_team_message(*, target_user_id: int, text: str) -> dict[str, Any]:
    return _request(
        "POST",
        "team-message",
        json_body={"target_user_id": int(target_user_id), "text": text},
    )


def send_direct_message(
    *,
    sender_user_id: int,
    target_user_id: int,
    text: str,
    message_type: str = "text",
    attachment_url: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return _request(
        "POST",
        "direct-message",
        json_body={
            "sender_user_id": int(sender_user_id),
            "target_user_id": int(target_user_id),
            "text": text,
            "message_type": message_type,
            "attachment_url": attachment_url,
            "metadata": dict(metadata or {}),
        },
    )


def patch_message(
    message_id: str,
    *,
    text: str | None = None,
    metadata_patch: dict[str, Any] | None = None,
) -> dict[str, Any]:
    body: dict[str, Any] = {"metadata_patch": dict(metadata_patch or {})}
    if text is not None:
        body["text"] = text
    return _request("PATCH", f"messages/{message_id}", json_body=body)


def mark_media_expired(
    *,
    attachment_url: str,
    media_id: str,
    expired_at: str,
    local_first_allowed: bool = True,
) -> int:
    result = _request(
        "POST",
        "media-expired",
        json_body={
            "attachment_url": attachment_url,
            "media_id": media_id,
            "expired_at": expired_at,
            "local_first_allowed": local_first_allowed,
        },
    )
    return int(result.get("updated") or 0)


def sync_family(
    *,
    family_id: int,
    title: str,
    member_user_ids: list[int],
) -> str:
    result = _request(
        "POST",
        f"family/{int(family_id)}/sync",
        json_body={"title": title, "member_user_ids": member_user_ids},
    )
    return str(result.get("conversation_id") or "")


def get_family_messages(
    *,
    family_id: int,
    user_id: int,
    limit: int,
    before: str | None = None,
) -> dict[str, Any]:
    params: dict[str, Any] = {
        "user_id": int(user_id),
        "limit": max(1, min(int(limit), 100)),
    }
    if before:
        params["before"] = before
    return _request(
        "GET",
        f"family/{int(family_id)}/messages",
        params=params,
    )


def send_family_message(
    *,
    family_id: int,
    sender_user_id: int,
    title: str,
    member_user_ids: list[int],
    text: str,
) -> dict[str, Any]:
    return _request(
        "POST",
        f"family/{int(family_id)}/messages",
        json_body={
            "sender_user_id": int(sender_user_id),
            "title": title,
            "member_user_ids": member_user_ids,
            "text": text,
        },
    )
