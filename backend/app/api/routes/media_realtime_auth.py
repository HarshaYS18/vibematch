import hmac

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.core.config import settings
from app.core.redis_client import get_redis
from app.database import get_db
from app.models.user import User
from app.schemas.media_realtime_auth import MediaRealtimeVerifyRequest, MediaRealtimeVerifyResponse
from app.services import media_node_registry_service
from app.services.media_realtime_auth_service import verify_media_realtime_request

router = APIRouter(prefix="/media-realtime", tags=["Media Realtime Auth"])


def _verify_media_node_identity(http_request: Request, payload: MediaRealtimeVerifyRequest) -> None:
    node_id = (payload.media_node_id or "").strip()
    if not node_id:
        return

    configured = settings.MEDIA_INTERNAL_TOKEN.encode("utf-8")
    supplied = http_request.headers.get("x-media-internal-token", "").encode("utf-8")
    if not configured or not supplied or not hmac.compare_digest(configured, supplied):
        raise HTTPException(status_code=403, detail="Invalid media node identity.")

    room_public_id = (payload.room_public_id or "").strip()
    if room_public_id:
        try:
            assigned = media_node_registry_service.room_is_assigned_to_node(
                get_redis(),
                room_public_id,
                node_id,
            )
        except media_node_registry_service.MediaNodeUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        if not assigned:
            raise HTTPException(
                status_code=409,
                detail="Room is assigned to a different media node. Resolve the room media endpoint again.",
            )


@router.post("/verify", response_model=MediaRealtimeVerifyResponse)
def verify_media_realtime_access(
    payload: MediaRealtimeVerifyRequest,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Verify user permissions and, for media servers, sticky node ownership."""
    _verify_media_node_identity(http_request, payload)

    result = verify_media_realtime_request(
        db=db,
        user=current_user,
        room_public_id=payload.room_public_id,
        requested_action=payload.requested_action,
        device_id=payload.device_id,
    )
    return MediaRealtimeVerifyResponse(**result)
