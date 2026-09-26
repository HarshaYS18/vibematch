"""Short-lived Ed25519 realtime capabilities issued by the auth control plane.

Access tokens remain API credentials. Realtime capabilities are deliberately
narrow transport grants so the Go gateway can verify connect/room subscription
permissions locally without periodic HTTP authorization.
"""

from __future__ import annotations

import base64
import hashlib
import json
import time
from dataclasses import dataclass

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from app.core.config import settings


_CAPABILITY_TYPE = "realtime_capability"


@dataclass(frozen=True)
class IssuedRealtimeCapability:
    token: str
    expires_at: int
    session_id: str


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _decode_b64url(value: str) -> bytes:
    text = value.strip()
    padding = "=" * ((4 - len(text) % 4) % 4)
    return base64.urlsafe_b64decode(text + padding)


def _private_seed() -> bytes:
    configured = settings.REALTIME_CAPABILITY_PRIVATE_KEY_B64.strip()
    if configured:
        try:
            seed = _decode_b64url(configured)
        except Exception as exc:
            raise RuntimeError("REALTIME_CAPABILITY_PRIVATE_KEY_B64 is invalid") from exc
        if len(seed) != 32:
            raise RuntimeError("REALTIME_CAPABILITY_PRIVATE_KEY_B64 must decode to 32 bytes")
        return seed

    if settings.is_production:
        raise RuntimeError("REALTIME_CAPABILITY_PRIVATE_KEY_B64 is required in production")

    # Local/test-only deterministic fallback. Production validation forbids it.
    return hashlib.sha256(
        ("funkey-realtime-capability:" + settings.JWT_SECRET_KEY).encode("utf-8")
    ).digest()


def _private_key() -> Ed25519PrivateKey:
    return Ed25519PrivateKey.from_private_bytes(_private_seed())


def public_jwk() -> dict[str, object]:
    public_key = _private_key().public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    return {
        "kty": "OKP",
        "crv": "Ed25519",
        "alg": "EdDSA",
        "use": "sig",
        "kid": settings.REALTIME_CAPABILITY_KEY_ID,
        "x": _b64url(public_key),
        "issuer": settings.REALTIME_CAPABILITY_ISSUER,
        "audience": settings.REALTIME_CAPABILITY_AUDIENCE,
        "token_version": settings.REALTIME_CAPABILITY_TOKEN_VERSION,
    }


def session_id_for_access_token(access_token: str) -> str:
    """Opaque per-access-token session identifier; never exposes the token."""

    return hashlib.sha256(access_token.encode("utf-8")).hexdigest()[:32]


def issue_realtime_capability(
    *,
    access_token: str,
    user_id: int,
    device_id: str,
    is_staff: bool,
    scopes: list[str],
    room_id: str | None = None,
    permissions: list[str] | None = None,
    membership_version: int | None = None,
) -> IssuedRealtimeCapability:
    now = int(time.time())
    expires_at = now + int(settings.REALTIME_CAPABILITY_TTL_SECONDS)
    session_id = session_id_for_access_token(access_token)
    payload: dict[str, object] = {
        "iss": settings.REALTIME_CAPABILITY_ISSUER,
        "aud": settings.REALTIME_CAPABILITY_AUDIENCE,
        "sub": str(int(user_id)),
        "type": _CAPABILITY_TYPE,
        "user_id": int(user_id),
        "session_id": session_id,
        "device_id": device_id,
        "scopes": list(dict.fromkeys(scope for scope in scopes if scope)),
        "iat": now,
        "nbf": now - 5,
        "exp": expires_at,
        "token_version": int(settings.REALTIME_CAPABILITY_TOKEN_VERSION),
        "is_staff": bool(is_staff),
    }
    if room_id:
        payload["room_id"] = room_id
        payload["permissions"] = list(
            dict.fromkeys(permission for permission in (permissions or []) if permission)
        )
        payload["membership_version"] = int(membership_version or 0)

    header = {
        "alg": "EdDSA",
        "typ": "JWT",
        "kid": settings.REALTIME_CAPABILITY_KEY_ID,
    }
    encoded_header = _b64url(
        json.dumps(header, separators=(",", ":"), sort_keys=True).encode("utf-8")
    )
    encoded_payload = _b64url(
        json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    )
    signing_input = f"{encoded_header}.{encoded_payload}".encode("ascii")
    signature = _private_key().sign(signing_input)
    return IssuedRealtimeCapability(
        token=f"{encoded_header}.{encoded_payload}.{_b64url(signature)}",
        expires_at=expires_at,
        session_id=session_id,
    )
