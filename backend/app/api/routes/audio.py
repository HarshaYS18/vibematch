from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from jose import jwt

from app.api.routes.users import get_current_user
from app.core.config import settings
from app.models.user import User


router = APIRouter(prefix="/audio", tags=["Audio"])


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

    expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
    public_user_id = str(current_user.public_user_id)

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
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )

    return {
        "audio_token": token,
        "room_id": room_id,
        "peer_id": public_user_id,
        "engine": "mediasoup",
        "expires_at": expires_at.isoformat(),
    }
