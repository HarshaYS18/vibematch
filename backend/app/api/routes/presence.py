from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.room import Room
from app.models.user import User

router = APIRouter(prefix="/presence", tags=["Presence"])

class PresenceHeartbeatResponse(BaseModel):
    status: str
    user_id: int
    last_seen_at: datetime
    is_online: bool

class RoomPresenceRequest(BaseModel):
    room_id: str | None = None
    room_public_id: str | None = None

class RoomPresenceResponse(BaseModel):
    status: str
    user_id: int
    room_public_id: str | None
    last_seen_at: datetime

def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)

def _touch_user(db: Session, user: User) -> datetime:
    now = _now()
    user.last_seen_at = now
    db.add(user)
    db.commit()
    db.refresh(user)
    return user.last_seen_at or now

def _room_public_id(payload: RoomPresenceRequest) -> str | None:
    return payload.room_public_id or payload.room_id

@router.post("/heartbeat", response_model=PresenceHeartbeatResponse)
def presence_heartbeat(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    last_seen_at = _touch_user(db, current_user)
    return PresenceHeartbeatResponse(status="ok", user_id=current_user.id, last_seen_at=last_seen_at, is_online=True)

@router.get("/me", response_model=PresenceHeartbeatResponse)
def get_my_presence(current_user: User = Depends(get_current_user)):
    now = _now()
    return PresenceHeartbeatResponse(status="ok", user_id=current_user.id, last_seen_at=current_user.last_seen_at or now, is_online=True)

@router.post("/room/enter", response_model=RoomPresenceResponse)
def enter_room_presence(payload: RoomPresenceRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    room_id = _room_public_id(payload)
    if room_id:
        room = db.query(Room).filter(Room.room_public_id == room_id).first()
        if room:
            room.online_count = max(1, room.online_count)
            db.add(room)
    last_seen_at = _touch_user(db, current_user)
    return RoomPresenceResponse(status="entered", user_id=current_user.id, room_public_id=room_id, last_seen_at=last_seen_at)

@router.post("/room/leave", response_model=RoomPresenceResponse)
def leave_room_presence(payload: RoomPresenceRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    room_id = _room_public_id(payload)
    if room_id:
        room = db.query(Room).filter(Room.room_public_id == room_id).first()
        if room:
            room.online_count = max(0, room.online_count - 1)
            db.add(room)
    last_seen_at = _touch_user(db, current_user)
    return RoomPresenceResponse(status="left", user_id=current_user.id, room_public_id=room_id, last_seen_at=last_seen_at)
