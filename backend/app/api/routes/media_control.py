import hmac
import logging
import time

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.core.config import settings
from app.core.redis_client import get_media_registry_redis, get_realtime_redis
from app.database import get_db
from app.models.user import User
from app.realtime.connection_manager import has_active_room_user_lease
from app.schemas.media_node import (
    MediaNodeDrainRequest,
    MediaNodeHeartbeatRequest,
    MediaNodeResponse,
    RoomMediaAssignmentResponse,
)
from app.services import media_node_registry_service
from app.services.media_realtime_auth_service import verify_media_realtime_request


router = APIRouter(tags=["Room Media"])
logger = logging.getLogger("uvicorn.error")


def _log_heartbeat_sent(request_id: str, started: float) -> None:
    logger.info(
        "media_registry.heartbeat.response_sent request_id=%s elapsed_ms=%.1f",
        request_id,
        (time.monotonic() - started) * 1000,
    )


def _internal_media_auth(request: Request) -> None:
    configured = settings.MEDIA_INTERNAL_TOKEN.encode("utf-8")
    supplied = request.headers.get("x-media-internal-token", "").encode("utf-8")
    if not configured or not supplied or not hmac.compare_digest(configured, supplied):
        raise HTTPException(status_code=403, detail="Invalid media internal token.")


def _node_response(node: media_node_registry_service.MediaNode) -> MediaNodeResponse:
    return MediaNodeResponse(**node.__dict__)


@router.get(
    "/rooms/{room_public_id}/media",
    response_model=RoomMediaAssignmentResponse,
)
def resolve_room_media(
    room_public_id: str,
    device_id: str | None = Query(default=None, max_length=255),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    realtime_redis = get_realtime_redis()
    media_registry_redis = get_media_registry_redis()
    permission = verify_media_realtime_request(
        db=db,
        user=current_user,
        room_public_id=room_public_id,
        requested_action="join_room",
        device_id=device_id,
        has_active_room_connection=has_active_room_user_lease(
            realtime_redis,
            room_public_id,
            current_user.id,
        ),
    )
    if not permission["allowed"]:
        raise HTTPException(status_code=403, detail=permission["reason"] or "Room media access denied.")

    try:
        node = media_node_registry_service.resolve_room_node(media_registry_redis, room_public_id)
    except media_node_registry_service.MediaNodeUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    return RoomMediaAssignmentResponse(
        room_public_id=room_public_id,
        node_id=node.node_id,
        signaling_url=node.public_url,
        assignment_ttl_seconds=settings.MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS,
    )


@router.post(
    "/internal/media/nodes/heartbeat",
    response_model=MediaNodeResponse,
    include_in_schema=False,
)
def media_node_heartbeat(payload: MediaNodeHeartbeatRequest, request: Request, background_tasks: BackgroundTasks):
    started = time.monotonic()
    request_id = request.headers.get("x-request-id", "-")[:64]
    if settings.MEDIA_REGISTRY_TRACE:
        logger.info("media_registry.heartbeat.received request_id=%s node_id=%s", request_id, payload.node_id)
    _internal_media_auth(request)
    try:
        if settings.MEDIA_REGISTRY_TRACE:
            logger.info("media_registry.heartbeat.redis_start request_id=%s", request_id)
        node = media_node_registry_service.heartbeat_node(
            get_media_registry_redis(),
            node_id=payload.node_id,
            public_url=str(payload.public_url),
            room_count=payload.room_count,
            peer_count=payload.peer_count,
            max_rooms=payload.max_rooms,
            max_peers=payload.max_peers,
            room_ids=payload.room_ids,
        )
    except media_node_registry_service.MediaNodeUnavailable as exc:
        logger.warning("media_registry.heartbeat.failed request_id=%s elapsed_ms=%.1f", request_id, (time.monotonic() - started) * 1000)
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    if settings.MEDIA_REGISTRY_TRACE:
        logger.info("media_registry.heartbeat.redis_complete request_id=%s elapsed_ms=%.1f", request_id, (time.monotonic() - started) * 1000)
        background_tasks.add_task(_log_heartbeat_sent, request_id, started)
    return _node_response(node)


@router.delete(
    "/internal/media/nodes/{node_id}",
    include_in_schema=False,
)
def media_node_offline(node_id: str, request: Request):
    _internal_media_auth(request)
    try:
        media_node_registry_service.remove_node(get_media_registry_redis(), node_id)
    except media_node_registry_service.MediaNodeUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return {"ok": True, "node_id": node_id}


@router.post(
    "/internal/media/nodes/{node_id}/drain",
    response_model=MediaNodeResponse,
    include_in_schema=False,
)
def media_node_internal_drain(node_id: str, request: Request):
    """Called by the media node before Kubernetes removes it from service."""
    _internal_media_auth(request)
    try:
        node = media_node_registry_service.set_node_draining(get_media_registry_redis(), node_id, True)
    except media_node_registry_service.MediaNodeUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return _node_response(node)


@router.get("/admin/media/nodes", response_model=list[MediaNodeResponse], tags=["Admin Media"])
def admin_list_media_nodes(
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    try:
        return [_node_response(node) for node in media_node_registry_service.list_nodes(get_media_registry_redis())]
    except media_node_registry_service.MediaNodeUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.patch("/admin/media/nodes/{node_id}/drain", response_model=MediaNodeResponse, tags=["Admin Media"])
def admin_set_media_node_drain(
    node_id: str,
    payload: MediaNodeDrainRequest,
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    try:
        node = media_node_registry_service.set_node_draining(get_media_registry_redis(), node_id, payload.draining)
    except media_node_registry_service.MediaNodeUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return _node_response(node)
