import json
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


def upsert_device_token(
    db: Session,
    *,
    user: User,
    device_id: str,
    platform: str,
    fcm_token: str,
    app_package: str | None = None,
) -> PushDeviceToken:
    token = db.query(PushDeviceToken).filter(PushDeviceToken.fcm_token == fcm_token).first()
    if token is None:
        token = PushDeviceToken(fcm_token=fcm_token)

    token.user_id = user.id
    token.device_id = device_id.strip()
    token.platform = platform.strip().lower()
    token.app_package = app_package.strip() if app_package else None
    token.is_active = True
    token.last_seen_at = datetime.utcnow()

    db.add(token)
    db.commit()
    db.refresh(token)
    return token


def deactivate_device_token(db: Session, *, user: User, device_id: str) -> None:
    tokens = (
        db.query(PushDeviceToken)
        .filter(PushDeviceToken.user_id == user.id, PushDeviceToken.device_id == device_id)
        .all()
    )
    for token in tokens:
        token.is_active = False
        db.add(token)
    db.commit()


def active_tokens_for_user(db: Session, user_id: int) -> list[PushDeviceToken]:
    return (
        db.query(PushDeviceToken)
        .filter(PushDeviceToken.user_id == user_id, PushDeviceToken.is_active.is_(True))
        .all()
    )


def send_to_user(db: Session, *, user_id: int, title: str, body: str, data: dict[str, Any]) -> None:
    for token in active_tokens_for_user(db, user_id):
        ok = send_fcm_message(token.fcm_token, title=title, body=body, data=data)
        if not ok:
            token.is_active = False
            db.add(token)
    db.commit()


def send_fcm_message(fcm_token: str, *, title: str, body: str, data: dict[str, Any]) -> bool:
    project_id = settings.FCM_PROJECT_ID.strip()
    service_account_path = settings.FIREBASE_SERVICE_ACCOUNT_PATH.strip()
    if not project_id or not service_account_path:
        return False

    path = Path(service_account_path)
    if not path.is_absolute():
        path = Path.cwd() / path
    if not path.exists():
        return False

    credentials = service_account.Credentials.from_service_account_file(
        str(path),
        scopes=[FCM_SCOPE],
    )
    credentials.refresh(Request())

    safe_data = {key: "" if value is None else str(value) for key, value in data.items()}
    response = requests.post(
        f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send",
        headers={
            "Authorization": f"Bearer {credentials.token}",
            "Content-Type": "application/json; UTF-8",
        },
        data=json.dumps(
            {
                "message": {
                    "token": fcm_token,
                    "notification": {
                        "title": title,
                        "body": body,
                    },
                    "data": safe_data,
                    "android": {
                        "priority": "HIGH",
                        "notification": {
                            "channel_id": "funkey_incoming_calls",
                            "click_action": "FLUTTER_NOTIFICATION_CLICK",
                        },
                    },
                }
            }
        ),
        timeout=10,
    )

    return 200 <= response.status_code < 300
