from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
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

class PublicPresenceResponse(BaseModel):
    public_user_id: int
    is_online: bool
    last_seen_at: datetime | None
    last_seen_text: str
    current_room_public_id: str | None = None
    current_room_name: str | None = None

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

def _last_seen_text(value: datetime | None) -> str:
    if value is None:
        return "offline"
    seconds = max(0, int((_now() - value).total_seconds()))
    if seconds < 90:
        return "online"
    minutes = seconds // 60
    if minutes < 60:
        return f"last seen {minutes} min ago"
    hours = minutes // 60
    if hours < 24:
        return f"last seen {hours} hour ago" if hours == 1 else f"last seen {hours} hours ago"
    days = hours // 24
    if days < 30:
        return f"last seen {days} day ago" if days == 1 else f"last seen {days} days ago"
    return "last seen a month ago"

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

@router.get("/public/{public_user_id}", response_model=PublicPresenceResponse)
def get_public_presence(public_user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    online = bool(user.last_seen_at and (_now() - user.last_seen_at).total_seconds() < 90)
    return PublicPresenceResponse(
        public_user_id=user.public_user_id,
        is_online=online,
        last_seen_at=user.last_seen_at,
        last_seen_text="online" if online else _last_seen_text(user.last_seen_at),
    )
