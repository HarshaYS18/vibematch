from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.presence import UserRoomPresence
from app.models.room import RoomMode
from app.models.user import User
from app.schemas.presence import (
    PresenceBatchRequest,
    PresenceBatchResponse,
    PresenceHeartbeatRequest,
    PresenceResponse,
    RoomPresenceEnterRequest,
)

router = APIRouter(prefix="/presence", tags=["Presence"])

_ONLINE_WINDOW_SECONDS = 120
_ROOM_ACTIVE_WINDOW_SECONDS = 150


def _now() -> datetime:
    return datetime.utcnow()


def _active_room_presence(db: Session, user_id: int) -> UserRoomPresence | None:
    cutoff = _now() - timedelta(seconds=_ROOM_ACTIVE_WINDOW_SECONDS)
    return (
        db.query(UserRoomPresence)
        .filter(
            UserRoomPresence.user_id == user_id,
            UserRoomPresence.is_active.is_(True),
            UserRoomPresence.last_heartbeat_at >= cutoff,
        )
        .order_by(UserRoomPresence.last_heartbeat_at.desc())
        .first()
    )


def _close_other_active_room_presence(db: Session, user_id: int, except_room_public_id: str | None = None) -> None:
    active_items = (
        db.query(UserRoomPresence)
        .filter(
            UserRoomPresence.user_id == user_id,
            UserRoomPresence.is_active.is_(True),
        )
        .all()
    )
    now = _now()
    for item in active_items:
        if except_room_public_id is not None and item.room_public_id == except_room_public_id:
            continue
        item.is_active = False
        item.left_at = now


def _presence_payload(user: User, room: UserRoomPresence | None, viewer: User | None = None) -> PresenceResponse:
    now = _now()
    is_online = user.last_seen_at is not None and user.last_seen_at >= now - timedelta(seconds=_ONLINE_WINDOW_SECONDS)

    visible_room = room is not None
    if room is not None and room.is_secret:
        # Secret Vibe room presence must not leak publicly.
        # Later we can allow room owner/admin/invite-authorized viewers here.
        visible_room = viewer is not None and viewer.id == user.id

    return PresenceResponse(
        public_user_id=user.public_user_id,
        is_online=is_online,
        last_seen_at=user.last_seen_at,
        in_room=visible_room,
        room_public_id=room.room_public_id if visible_room and room is not None else None,
        room_name=room.room_name if visible_room and room is not None else None,
        room_mode=room.room_mode if visible_room and room is not None else None,
        room_entered_at=room.entered_at if visible_room and room is not None else None,
    )


def _touch_user(db: Session, user: User) -> None:
    user.last_seen_at = _now()
    db.add(user)


@router.post("/heartbeat", response_model=PresenceResponse)
def heartbeat(
    payload: PresenceHeartbeatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _touch_user(db, current_user)

    room: UserRoomPresence | None = None
    if payload.room_public_id and payload.room_name:
        room_public_id = payload.room_public_id.strip()
        room_name = payload.room_name.strip()

        if room_public_id and room_name:
            _close_other_active_room_presence(db, current_user.id, except_room_public_id=room_public_id)

            room = (
                db.query(UserRoomPresence)
                .filter(
                    UserRoomPresence.user_id == current_user.id,
                    UserRoomPresence.room_public_id == room_public_id,
                    UserRoomPresence.is_active.is_(True),
                )
                .first()
            )

            now = _now()
            if room is None:
                room = UserRoomPresence(
                    user_id=current_user.id,
                    room_public_id=room_public_id,
                    room_name=room_name,
                    room_mode=payload.room_mode,
                    is_secret=payload.is_secret,
                    is_active=True,
                    entered_at=now,
                    last_heartbeat_at=now,
                )
                db.add(room)
            else:
                room.room_name = room_name
                room.room_mode = payload.room_mode
                room.is_secret = payload.is_secret
                room.last_heartbeat_at = now
                db.add(room)

    db.commit()
    db.refresh(current_user)
    if room is None:
        room = _active_room_presence(db, current_user.id)
    return _presence_payload(current_user, room, current_user)


@router.post("/room/enter", response_model=PresenceResponse)
def enter_room_presence(
    payload: RoomPresenceEnterRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room_public_id = payload.room_public_id.strip()
    room_name = payload.room_name.strip()
    if not room_public_id or not room_name:
        raise HTTPException(status_code=400, detail="Room id and name are required")

    _touch_user(db, current_user)
    _close_other_active_room_presence(db, current_user.id, except_room_public_id=room_public_id)

    now = _now()
    room = (
        db.query(UserRoomPresence)
        .filter(
            UserRoomPresence.user_id == current_user.id,
            UserRoomPresence.room_public_id == room_public_id,
            UserRoomPresence.is_active.is_(True),
        )
        .first()
    )
    if room is None:
        room = UserRoomPresence(
            user_id=current_user.id,
            room_public_id=room_public_id,
            room_name=room_name,
            room_mode=payload.room_mode,
            is_secret=payload.is_secret,
            is_active=True,
            entered_at=now,
            last_heartbeat_at=now,
        )
        db.add(room)
    else:
        room.room_name = room_name
        room.room_mode = payload.room_mode
        room.is_secret = payload.is_secret
        room.last_heartbeat_at = now
        db.add(room)

    db.commit()
    db.refresh(current_user)
    return _presence_payload(current_user, room, current_user)


@router.post("/room/leave", response_model=PresenceResponse)
def leave_room_presence(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _touch_user(db, current_user)
    _close_other_active_room_presence(db, current_user.id)
    db.commit()
    db.refresh(current_user)
    return _presence_payload(current_user, None, current_user)


@router.get("/public/{public_user_id}", response_model=PresenceResponse)
def get_public_presence(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = (
        db.query(User)
        .filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False))
        .first()
    )
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    room = _active_room_presence(db, user.id)
    return _presence_payload(user, room, current_user)


@router.post("/batch", response_model=PresenceBatchResponse)
def get_batch_presence(
    payload: PresenceBatchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    public_ids = list(dict.fromkeys(payload.public_user_ids))[:100]
    if not public_ids:
        return PresenceBatchResponse(items=[])

    users = (
        db.query(User)
        .filter(User.public_user_id.in_(public_ids), User.is_active.is_(True), User.is_banned.is_(False))
        .all()
    )

    items: list[PresenceResponse] = []
    for user in users:
        room = _active_room_presence(db, user.id)
        items.append(_presence_payload(user, room, current_user))

    return PresenceBatchResponse(items=items)
