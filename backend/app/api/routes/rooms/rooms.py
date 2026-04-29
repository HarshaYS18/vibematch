from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.rooms.room import RoomTrendingResponse
from app.schemas.rooms.room_kickout import (
    RoomKickoutCreateRequest,
    RoomKickoutResponse,
)
from app.services.rooms.room_kickout_service import (
    create_room_kickout,
    list_active_room_kickouts,
)
from app.services.rooms.room_service import list_trending_rooms


router = APIRouter(prefix="/rooms", tags=["Rooms"])


@router.get("/trending", response_model=list[RoomTrendingResponse])
def get_trending_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return list_trending_rooms(
        db=db,
        language=language,
        category=category,
        limit=limit,
    )


@router.post(
    "/{room_public_id}/kickouts",
    response_model=RoomKickoutResponse,
)
def kickout_room_user(
    room_public_id: str,
    payload: RoomKickoutCreateRequest,
    db: Session = Depends(get_db),
):
    """
    Kick a user out of a room and add them to that room's blocked list.

    Durations:
    - 1h: blocked for 1 hour
    - 1d: blocked for 1 day
    - forever: blocked until manually removed later

    Temporary dev contract: actor identity will be connected to auth dependency
    after room permissions are wired.
    """

    return create_room_kickout(
        db=db,
        room_public_id=room_public_id,
        payload=payload,
    )


@router.get(
    "/{room_public_id}/kickouts",
    response_model=list[RoomKickoutResponse],
)
def get_room_blocked_users(
    room_public_id: str,
    db: Session = Depends(get_db),
):
    """Return active kick-out/blocked-list entries for room settings."""

    return list_active_room_kickouts(
        db=db,
        room_public_id=room_public_id,
    )
