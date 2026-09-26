from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
from jose import JWTError, jwt

from app.core.config import settings


_BCRYPT_MAX_PASSWORD_BYTES = 72


def _bcrypt_secret(password: str) -> bytes:
    secret = (password or "").encode("utf-8")
    if len(secret) > _BCRYPT_MAX_PASSWORD_BYTES:
        raise ValueError("Password must be 72 bytes or fewer for bcrypt.")
    return secret


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_bcrypt_secret(password), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        expected = (password_hash or "").encode("utf-8")
        if not expected.startswith((b"$2a$", b"$2b$", b"$2y$")):
            return False
        return bcrypt.checkpw(_bcrypt_secret(password), expected)
    except (TypeError, ValueError):
        return False


def create_access_token(
    subject: str,
    expires_minutes: Optional[int] = None,
    device_id: str | None = None,
    session_id: str | None = None,
) -> str:
    expire_minutes = expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    expire = datetime.now(timezone.utc) + timedelta(minutes=expire_minutes)

    payload = {
        "sub": subject,
        "exp": expire,
        "type": "access",
    }
    if device_id:
        payload["device_id"] = device_id
    if session_id:
        payload["sid"] = session_id

    return jwt.encode(
        payload,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


def decode_access_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
    except JWTError:
        return None
