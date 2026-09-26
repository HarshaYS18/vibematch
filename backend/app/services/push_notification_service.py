import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.push_device_token import PushDeviceToken
from app.models.user import User

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


@dataclass(frozen=True)
class FcmSendResult:
    ok: bool
    retryable: bool = False
    invalid_token: bool = False
    code: str | None = None
    provider_message_id: str | None = None
    detail: str | None = None


def assert_firebase_configuration(
    project_id: str | None = None,
    service_account_path: str | None = None,
) -> None:
    configured_project = (settings.FCM_PROJECT_ID if project_id is None else project_id).strip()
    configured_path = (settings.FIREBASE_SERVICE_ACCOUNT_PATH if service_account_path is None else service_account_path).strip()
    if not configured_project and not configured_path:
        return
    if not configured_project or not configured_path:
        raise RuntimeError("FCM_PROJECT_ID and FIREBASE_SERVICE_ACCOUNT_PATH must be configured together.")
    path = Path(configured_path)
    if not path.is_absolute():
        path = Path.cwd() / path
    if not path.is_file():
        raise RuntimeError("Firebase service account file is missing.")
    try:
        credentials = service_account.Credentials.from_service_account_file(str(path), scopes=[FCM_SCOPE])
    except Exception:
        raise RuntimeError("Firebase service account file is invalid.") from None
    if credentials.project_id != configured_project:
        raise RuntimeError("Firebase service account project does not match FCM_PROJECT_ID.")


def upsert_device_token(
    db: Session,
    *,
    user: User,
    device_id: str,
    platform: str,
    fcm_token: str,
    app_package: str | None = None,
) -> PushDeviceToken:
    normalized_device = device_id.strip()
    for previous in (
        db.query(PushDeviceToken)
        .filter(
            PushDeviceToken.user_id == user.id,
            PushDeviceToken.device_id == normalized_device,
            PushDeviceToken.fcm_token != fcm_token,
            PushDeviceToken.is_active.is_(True),
        )
        .all()
    ):
        previous.is_active = False
        db.add(previous)

    token = db.query(PushDeviceToken).filter(PushDeviceToken.fcm_token == fcm_token).first()
    if token is None:
        token = PushDeviceToken(fcm_token=fcm_token)

    token.user_id = user.id
    token.device_id = normalized_device
    token.platform = platform.strip().lower()
    token.app_package = app_package.strip() if app_package else None
    token.is_active = True
    token.last_seen_at = datetime.utcnow()

    db.add(token)
    db.commit()
    db.refresh(token)
    return token


def deactivate_device_token(db: Session, *, user: User, device_id: str) -> None:
    (
        db.query(PushDeviceToken)
        .filter(PushDeviceToken.user_id == user.id, PushDeviceToken.device_id == device_id)
        .update({PushDeviceToken.is_active: False}, synchronize_session=False)
    )
    db.commit()


def active_tokens_for_user(db: Session, user_id: int) -> list[PushDeviceToken]:
    return (
        db.query(PushDeviceToken)
        .filter(PushDeviceToken.user_id == user_id, PushDeviceToken.is_active.is_(True))
        .all()
    )


def _fcm_error(payload: dict) -> tuple[str | None, bool]:
    error = payload.get("error") if isinstance(payload, dict) else None
    if not isinstance(error, dict):
        return None, False
    status = str(error.get("status") or "") or None
    fcm_code = None
    for detail in error.get("details") or []:
        if isinstance(detail, dict) and str(detail.get("@type", "")).endswith("FcmError"):
            fcm_code = str(detail.get("errorCode") or "") or None
            break
    code = fcm_code or status
    return code, code in {"UNREGISTERED", "SENDER_ID_MISMATCH"}


def send_fcm_message_result(
    fcm_token: str,
    *,
    title: str,
    body: str,
    data: dict[str, Any],
    collapse_key: str | None = None,
) -> FcmSendResult:
    project_id = settings.FCM_PROJECT_ID.strip()
    service_account_path = settings.FIREBASE_SERVICE_ACCOUNT_PATH.strip()
    if not project_id or not service_account_path:
        return FcmSendResult(ok=False, code="provider_not_configured", detail="FCM is not configured")

    path = Path(service_account_path)
    if not path.is_absolute():
        path = Path.cwd() / path
    if not path.exists():
        return FcmSendResult(ok=False, code="credentials_missing", detail="FCM credentials file is missing")

    try:
        credentials = service_account.Credentials.from_service_account_file(str(path), scopes=[FCM_SCOPE])
        credentials.refresh(Request())
    except Exception as exc:
        return FcmSendResult(ok=False, retryable=True, code="credentials_refresh", detail=type(exc).__name__)

    safe_data = {key: "" if value is None else str(value) for key, value in data.items()}
    android = {
        "priority": "HIGH",
        "notification": {
            "channel_id": "funkey_incoming_calls",
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
        },
    }
    apns: dict[str, Any] = {}
    if collapse_key:
        android["collapse_key"] = collapse_key[:120]
        apns["headers"] = {"apns-collapse-id": collapse_key[:64]}

    message: dict[str, Any] = {
        "token": fcm_token,
        "notification": {"title": title, "body": body},
        "data": safe_data,
        "android": android,
    }
    if apns:
        message["apns"] = apns

    try:
        response = requests.post(
            f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send",
            headers={
                "Authorization": f"Bearer {credentials.token}",
                "Content-Type": "application/json; UTF-8",
            },
            data=json.dumps({"message": message}),
            timeout=10,
        )
    except requests.RequestException as exc:
        return FcmSendResult(ok=False, retryable=True, code="network_error", detail=type(exc).__name__)

    try:
        response_payload = response.json()
    except ValueError:
        response_payload = {}

    if 200 <= response.status_code < 300:
        provider_id = response_payload.get("name") if isinstance(response_payload, dict) else None
        return FcmSendResult(ok=True, provider_message_id=str(provider_id) if provider_id else None)

    code, invalid = _fcm_error(response_payload)
    retryable = response.status_code == 429 or response.status_code >= 500 or code in {
        "UNAVAILABLE",
        "INTERNAL",
        "RESOURCE_EXHAUSTED",
    }
    detail = None
    if isinstance(response_payload, dict):
        error = response_payload.get("error")
        if isinstance(error, dict) and error.get("message"):
            detail = str(error["message"])[:500]
    return FcmSendResult(ok=False,retryable=retryable,invalid_token=invalid,code=code or f"http_{response.status_code}",detail=detail)


def send_fcm_message(fcm_token: str, *, title: str, body: str, data: dict[str, Any]) -> bool:
    return send_fcm_message_result(fcm_token,title=title,body=body,data=data).ok
