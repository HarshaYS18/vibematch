from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.presence import (
    PresenceBatchRequest,
    PresenceBatchResponse,
    PresenceHeartbeatRequest,
    PresenceResponse,
    RoomPresenceEnterRequest,
)
from app.services import presence_projection_service


router = APIRouter(prefix="/presence", tags=["Presence"])


def _presence_payload(
    user: User,
    projection: presence_projection_service.RealtimePresenceProjection,
    *,
    viewer_user_id: int | None = None,
) -> PresenceResponse:
    room = projection.room
    can_disclose_room = bool(
        room is not None
        and (not room.is_secret or viewer_user_id == user.id)
    )
    return PresenceResponse(
        public_user_id=user.public_user_id,
        is_online=bool(projection.is_online),
        last_seen_at=user.last_seen_at,
        in_room=can_disclose_room,
        room_public_id=room.room_public_id if can_disclose_room else None,
        room_name=room.name if can_disclose_room else None,
        room_mode=room.mode if can_disclose_room else None,
        room_entered_at=projection.room_entered_at if can_disclose_room else None,
    )


def _single_projection(db: Session, user: User):
    return presence_projection_service.project_user_presence(db, [user.id])[user.id]


@router.post("/heartbeat", response_model=PresenceResponse, deprecated=True)
def heartbeat(
    payload: PresenceHeartbeatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Read-only compatibility endpoint.

    Online state is owned by the authenticated Go realtime socket lease. Client
    metadata is intentionally ignored and this endpoint performs no writes.
    """
    del payload
    return _presence_payload(
        current_user,
        _single_projection(db, current_user),
        viewer_user_id=current_user.id,
    )


@router.post("/room/enter", response_model=PresenceResponse, deprecated=True)
def enter_room(
    payload: RoomPresenceEnterRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Read-only compatibility endpoint; Room Control + realtime own room entry."""
    del payload
    return _presence_payload(
        current_user,
        _single_projection(db, current_user),
        viewer_user_id=current_user.id,
    )


@router.post("/room/leave", response_model=PresenceResponse, deprecated=True)
def leave_room(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Read-only compatibility endpoint; Room Control + realtime own room exit."""
    return _presence_payload(
        current_user,
        _single_projection(db, current_user),
        viewer_user_id=current_user.id,
    )


@router.get("/public/{public_user_id}", response_model=PresenceResponse)
def public_presence(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return _presence_payload(
        user,
        _single_projection(db, user),
        viewer_user_id=current_user.id,
    )


@router.post("/batch", response_model=PresenceBatchResponse)
def batch_presence(
    payload: PresenceBatchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ids = list(dict.fromkeys(payload.public_user_ids))[:100]
    if not ids:
        return PresenceBatchResponse(items=[])

    users = db.query(User).filter(User.public_user_id.in_(ids)).all()
    by_public_id = {user.public_user_id: user for user in users}
    projections = presence_projection_service.project_user_presence(
        db,
        [user.id for user in users],
    )
    items = [
        _presence_payload(
            by_public_id[public_user_id],
            projections[by_public_id[public_user_id].id],
            viewer_user_id=current_user.id,
        )
        for public_user_id in ids
        if public_user_id in by_public_id
    ]
    return PresenceBatchResponse(items=items)
