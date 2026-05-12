from datetime import datetime
from app.schemas.room_settings import (
    RoomAnnouncementUpdateRequest,
    RoomBackgroundUpdateRequest,
    RoomSettingsResponse,
)
from app.models.room import Room
from app.database import get_db
from sqlalchemy.orm import Session
from fastapi import APIRouter, Depends, HTTPException

router = APIRouter(prefix="/rooms", tags=["rooms"])



def _get_room_by_public_id(db: Session, room_public_id: str) -> Room:
    room = (
        db.query(Room)
        .filter(Room.room_public_id == room_public_id)
        .first()
    )
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def _room_settings_response(room: Room) -> RoomSettingsResponse:
    return RoomSettingsResponse(
        room_public_id=room.room_public_id,
        background_theme_id=room.background_theme_id or "default",
        announcement_text=room.announcement_text,
        announcement_updated_at=room.announcement_updated_at,
        announcement_updated_by_user_id=room.announcement_updated_by_user_id,
    )


@router.get("/{room_public_id}/settings", response_model=RoomSettingsResponse)
def get_room_settings(
    room_public_id: str,
    db: Session = Depends(get_db),
) -> RoomSettingsResponse:
    room = _get_room_by_public_id(db, room_public_id)
    return _room_settings_response(room)


@router.patch("/{room_public_id}/background", response_model=RoomSettingsResponse)
def update_room_background(
    room_public_id: str,
    payload: RoomBackgroundUpdateRequest,
    db: Session = Depends(get_db),
) -> RoomSettingsResponse:
    room = _get_room_by_public_id(db, room_public_id)
    room.background_theme_id = payload.background_theme_id.strip() or "default"
    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_settings_response(room)


@router.patch("/{room_public_id}/announcement", response_model=RoomSettingsResponse)
def update_room_announcement(
    room_public_id: str,
    payload: RoomAnnouncementUpdateRequest,
    db: Session = Depends(get_db),
) -> RoomSettingsResponse:
    room = _get_room_by_public_id(db, room_public_id)
    text = payload.announcement_text.strip()
    room.announcement_text = text if text else None
    room.announcement_updated_at = datetime.utcnow()
    # TODO: replace with authenticated user id when room permissions are wired.
    room.announcement_updated_by_user_id = room.owner_user_id
    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_settings_response(room)
