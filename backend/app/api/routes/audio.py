from datetime import datetime, timedelta, timezone
from hashlib import sha256

from fastapi import APIRouter, Depends
from jose import jwt

from app.api.routes.users import get_current_user
from app.core.config import settings
from app.models.user import User


router = APIRouter(prefix="/audio", tags=["Audio"])


def _secret_fingerprint(secret: str) -> str:
    return sha256(secret.encode("utf-8")).hexdigest()[:12]


@router.post("/rooms/{room_id}/session")
def create_room_audio_session(
    room_id: str,
    current_user: User = Depends(get_current_user),
):
    """Issue a short-lived token for the standalone mediasoup audio service.

    Production note: this endpoint is the first integration layer. Later it must
    also validate room membership, locked room access, Secret Vibe permissions,
    room bans/mutes, and seat permission before allowing publish.
    """

    expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=settings.AUDIO_SESSION_EXPIRE_MINUTES,
    )
    public_user_id = str(current_user.public_user_id)
    audio_secret = settings.audio_jwt_secret_key
    audio_algorithm = settings.audio_jwt_algorithm

    payload = {
        "sub": str(current_user.id),
        "public_user_id": public_user_id,
        "room_id": room_id,
        "peer_id": public_user_id,
        "type": "audio_session",
        "engine": "mediasoup",
        "exp": expires_at,
    }

    token = jwt.encode(
        payload,
        audio_secret,
        algorithm=audio_algorithm,
    )

    return {
        "audio_token": token,
        "room_id": room_id,
        "peer_id": public_user_id,
        "engine": "mediasoup",
        "expires_at": expires_at.isoformat(),
        "algorithm": audio_algorithm,
        "secret_fingerprint": _secret_fingerprint(audio_secret),
    }


@router.get("/debug/config")
def get_audio_debug_config(
    current_user: User = Depends(get_current_user),
):
    """Safe local debug endpoint for matching backend and mediasoup token config.

    This returns only a short hash fingerprint, never the secret itself.
    """

    audio_secret = settings.audio_jwt_secret_key
    return {
        "ok": True,
        "engine": "mediasoup",
        "algorithm": settings.audio_jwt_algorithm,
        "secret_fingerprint": _secret_fingerprint(audio_secret),
        "session_expire_minutes": settings.AUDIO_SESSION_EXPIRE_MINUTES,
        "user_public_id": current_user.public_user_id,
    }
