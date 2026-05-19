from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.media_realtime_auth import MediaRealtimeVerifyRequest, MediaRealtimeVerifyResponse
from app.services.media_realtime_auth_service import verify_media_realtime_request

router = APIRouter(prefix="/media-realtime", tags=["Media Realtime Auth"])


@router.post("/verify", response_model=MediaRealtimeVerifyResponse)
def verify_media_realtime_access(
    request: MediaRealtimeVerifyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Verify JWT-backed access before mediasoup/signaling actions.

    A mediasoup signaling service should call this route with the user's Bearer
    token before allowing join, transport creation, produce, consume, or seat
    actions. The response returns backend-trusted user identity and permission
    context; signaling services must ignore any user identity sent by clients.
    """
    payload = verify_media_realtime_request(
        db=db,
        user=current_user,
        room_public_id=request.room_public_id,
        requested_action=request.requested_action,
        device_id=request.device_id,
    )
    return MediaRealtimeVerifyResponse(**payload)
