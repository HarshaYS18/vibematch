from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.room import Room, RoomMode, RoomType
from app.models.user import User
from app.schemas.rooms.room import RoomTrendingResponse
from app.schemas.rooms.room_kickout import (
    RoomKickoutCreateRequest,
    RoomKickoutResponse,
)
from app.services.rooms.room_kickout_service import (
    create_room_kickout,
    list_active_room_kickouts,
    remove_room_kickout,
)
from app.services.rooms.room_service import MOCK_TRENDING_ROOMS, list_trending_rooms


router = APIRouter(prefix="/rooms", tags=["Rooms"])


class RoomSettingsResponse(BaseModel):
    room_public_id: str
    name: str
    language: str
    mode: str
    room_type: str
    online_count: int
    image_messages_enabled: bool = True
    guest_messages_enabled: bool = True
    members_only: bool = False
    locked: bool = False
    secret_vibe: bool = False
    cricket_mode_enabled: bool = False
    watch_party_enabled: bool = False


class RoomActionResponse(BaseModel):
    status: str
    room_public_id: str
    online_count: int
    joined: bool = False
    message: str | None = None


def _room_from_mock(room_public_id: str) -> Room | None:
    for mock in MOCK_TRENDING_ROOMS:
        if mock.id == room_public_id:
            return Room(
                room_public_id=mock.id,
                owner_user_id=None,
                name=mock.name,
                subtitle=mock.subtitle,
                language=mock.language,
                mode=mock.mode,
                room_type=mock.type,
                online_count=mock.online_count,
                trending_score=mock.trending_score,
                is_active=True,
                is_secret=mock.mode == RoomMode.SECRET_VIBE.value,
                is_locked=mock.mode == RoomMode.LOCKED.value,
                is_members_only=mock.mode == RoomMode.MEMBERS_ONLY.value,
            )
    return None


def _get_or_create_room(db: Session, room_public_id: str, current_user: User | None = None) -> Room:
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if room:
        return room

    mock_room = _room_from_mock(room_public_id)
    if mock_room:
        db.add(mock_room)
        db.commit()
        db.refresh(mock_room)
        return mock_room

    room = Room(
        room_public_id=room_public_id,
        owner_user_id=current_user.id if current_user else None,
        name=f"Room {room_public_id}",
        subtitle="Live room session",
        language="All",
        mode=RoomMode.OPEN.value,
        room_type=RoomType.CHAT.value,
        online_count=0,
        trending_score=0,
        is_active=True,
        is_secret=False,
        is_locked=False,
        is_members_only=False,
    )
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def _settings_payload(room: Room) -> RoomSettingsResponse:
    return RoomSettingsResponse(
        room_public_id=room.room_public_id,
        name=room.name,
        language=room.language,
        mode=room.mode,
        room_type=room.room_type,
        online_count=room.online_count,
        members_only=room.is_members_only,
        locked=room.is_locked,
        secret_vibe=room.is_secret,
    )


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


@router.get("/{room_public_id}/settings", response_model=RoomSettingsResponse)
def get_room_settings(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_or_create_room(db, room_public_id, current_user)
    return _settings_payload(room)


@router.post("/{room_public_id}/join", response_model=RoomActionResponse)
def join_room(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_or_create_room(db, room_public_id, current_user)
    if not room.is_active:
        raise HTTPException(status_code=403, detail="Room is inactive")
    room.online_count = max(1, room.online_count + 1)
    room.updated_at = datetime.utcnow()
    db.add(room)
    current_user.last_seen_at = datetime.utcnow()
    db.add(current_user)
    db.commit()
    db.refresh(room)
    return RoomActionResponse(status="joined", room_public_id=room.room_public_id, online_count=room.online_count, joined=True)


@router.post("/{room_public_id}/leave", response_model=RoomActionResponse)
def leave_room(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_or_create_room(db, room_public_id, current_user)
    room.online_count = max(0, room.online_count - 1)
    room.updated_at = datetime.utcnow()
    db.add(room)
    current_user.last_seen_at = datetime.utcnow()
    db.add(current_user)
    db.commit()
    db.refresh(room)
    return RoomActionResponse(status="left", room_public_id=room.room_public_id, online_count=room.online_count, joined=False)


@router.post("/{room_public_id}/heartbeat", response_model=RoomActionResponse)
def room_heartbeat(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_or_create_room(db, room_public_id, current_user)
    current_user.last_seen_at = datetime.utcnow()
    db.add(current_user)
    db.commit()
    return RoomActionResponse(status="ok", room_public_id=room.room_public_id, online_count=room.online_count, joined=True)


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


@router.delete(
    "/{room_public_id}/kickouts/{kickout_id}",
    response_model=RoomKickoutResponse,
)
def unblock_room_user(
    room_public_id: str,
    kickout_id: int,
    db: Session = Depends(get_db),
):
    """
    Remove a user from this room's blocked list.

    Temporary dev contract: permission checks and audit logs will be connected
    after backend room roles are fully wired.
    """

    removed = remove_room_kickout(
        db=db,
        room_public_id=room_public_id,
        kickout_id=kickout_id,
    )

    if removed is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active room blocked-list entry not found.",
        )

    return removed
