import base64
import json
from datetime import datetime, timedelta
from typing import Any
from urllib.parse import urlencode

import requests
from cryptography.fernet import Fernet

from app.core.config import settings

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_DRIVE_FILES_URL = "https://www.googleapis.com/drive/v3/files"
GOOGLE_DRIVE_UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3/files"


def _fernet() -> Fernet:
    raw = settings.INBOX_BACKUP_ENCRYPTION_KEY.encode("utf-8")
    key = base64.urlsafe_b64encode(raw.ljust(32, b"0")[:32])
    return Fernet(key)


def encrypt_text(value: str) -> str:
    return _fernet().encrypt(value.encode("utf-8")).decode("utf-8")


def decrypt_text(value: str) -> str:
    return _fernet().decrypt(value.encode("utf-8")).decode("utf-8")


def build_authorization_url(state: str) -> str:
    if not settings.GOOGLE_DRIVE_CLIENT_ID:
        raise ValueError("GOOGLE_DRIVE_CLIENT_ID is not configured.")
    params = {
        "client_id": settings.GOOGLE_DRIVE_CLIENT_ID,
        "redirect_uri": settings.GOOGLE_DRIVE_REDIRECT_URI,
        "response_type": "code",
        "scope": settings.GOOGLE_DRIVE_SCOPES,
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
    }
    return f"{GOOGLE_AUTH_URL}?{urlencode(params)}"


def exchange_code_for_tokens(code: str) -> dict[str, Any]:
    if not settings.GOOGLE_DRIVE_CLIENT_ID or not settings.GOOGLE_DRIVE_CLIENT_SECRET:
        raise ValueError("Google Drive OAuth client ID/secret is not configured.")
    response = requests.post(
        GOOGLE_TOKEN_URL,
        data={
            "code": code,
            "client_id": settings.GOOGLE_DRIVE_CLIENT_ID,
            "client_secret": settings.GOOGLE_DRIVE_CLIENT_SECRET,
            "redirect_uri": settings.GOOGLE_DRIVE_REDIRECT_URI,
            "grant_type": "authorization_code",
        },
        timeout=20,
    )
    if response.status_code >= 300:
        raise ValueError(f"Google token exchange failed: {response.text}")
    return response.json()


def refresh_access_token(refresh_token: str) -> dict[str, Any]:
    response = requests.post(
        GOOGLE_TOKEN_URL,
        data={
            "client_id": settings.GOOGLE_DRIVE_CLIENT_ID,
            "client_secret": settings.GOOGLE_DRIVE_CLIENT_SECRET,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
        timeout=20,
    )
    if response.status_code >= 300:
        raise ValueError(f"Google token refresh failed: {response.text}")
    return response.json()


def get_profile_email(access_token: str) -> str | None:
    response = requests.get(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=20,
    )
    if response.status_code >= 300:
        return None
    data = response.json()
    return data.get("email")


def ensure_backup_folder(access_token: str, existing_folder_id: str | None = None) -> str:
    if existing_folder_id:
        return existing_folder_id
    metadata = {"name": "Vibe Match Inbox Backups", "mimeType": "application/vnd.google-apps.folder"}
    response = requests.post(
        GOOGLE_DRIVE_FILES_URL,
        headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
        json=metadata,
        timeout=20,
    )
    if response.status_code >= 300:
        raise ValueError(f"Google Drive folder create failed: {response.text}")
    return response.json()["id"]


def upload_backup_file(access_token: str, folder_id: str, filename: str, encrypted_json: dict[str, Any]) -> str:
    metadata = {"name": filename, "parents": [folder_id], "mimeType": "application/json"}
    files = {
        "metadata": ("metadata", json.dumps(metadata), "application/json; charset=UTF-8"),
        "file": (filename, json.dumps(encrypted_json), "application/json"),
    }
    response = requests.post(
        f"{GOOGLE_DRIVE_UPLOAD_URL}?uploadType=multipart&fields=id,name",
        headers={"Authorization": f"Bearer {access_token}"},
        files=files,
        timeout=30,
    )
    if response.status_code >= 300:
        raise ValueError(f"Google Drive backup upload failed: {response.text}")
    return response.json()["id"]


def download_backup_file(access_token: str, file_id: str) -> dict[str, Any]:
    response = requests.get(
        f"{GOOGLE_DRIVE_FILES_URL}/{file_id}?alt=media",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=30,
    )
    if response.status_code >= 300:
        raise ValueError(f"Google Drive backup download failed: {response.text}")
    return response.json()


def utc_expiry(seconds: int | None) -> str | None:
    if not seconds:
        return None
    return (datetime.utcnow() + timedelta(seconds=seconds)).isoformat()
