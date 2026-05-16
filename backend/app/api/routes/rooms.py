import random
from datetime import datetime, timedelta

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.core.security import hash_password
from app.database import get_db
from app.models.presence import UserRoomPresence
from app.models.room import Room
from app.models.user import User
from app.schemas.room_settings import (
    RoomAccessSettingsUpdateRequest,
    RoomAnnouncementUpdateRequest,
    RoomBackgroundUpdateRequest,
    RoomSeatLayoutUpdateRequest,
    RoomSettingsResponse,
)

router = APIRouter(prefix="/rooms", tags=["rooms"])
_ROOM_ACTIVE_WINDOW_SECONDS = 150
_NEW_ROOM_DISCOVERY_GRACE_SECONDS = 180
_ALLOWED_SEAT_LAYOUT_IDS = {"4x2", "5x2", "4x3", "5x3", "host_4x2", "host_5x2", "host_4x3", "host_5x3"}


def _get_room_by_public_id(db: Session, room_public_id: str) -> Room:
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def _clean_seat_layout_id(value: str | None) -> str:
    clean = (value or "5x2").strip()
    if clean not in _ALLOWED_SEAT_LAYOUT_IDS:
        raise HTTPException(status_code=400, detail="Unsupported room seat layout")
    return clean


def _active_room_count(db: Session, room_public_id: str) -> int:
    cutoff = datetime.utcnow() - timedelta(seconds=_ROOM_ACTIVE_WINDOW_SECONDS)
    return (
        db.query(UserRoomPresence.id)
        .filter(
            UserRoomPresence.room_public_id == room_public_id,
            UserRoomPresence.is_active.is_(True),
            UserRoomPresence.is_secret.is_(False),
            UserRoomPresence.last_heartbeat_at >= cutoff,
        )
        .count()
    )


def _get_or_create_room_for_settings(
    db: Session,
    room_public_id: str,
    current_user: User | None = None,
) -> Room:
    clean_room_public_id = room_public_id.strip()
    if not clean_room_public_id:
        raise HTTPException(status_code=400, detail="Room ID is required")

    room = db.query(Room).filter(Room.room_public_id == clean_room_public_id).first()
    if room is not None:
        return room

    owner_user_id = current_user.id if current_user is not None else None
    room = Room(
        room_public_id=clean_room_public_id,
        owner_user_id=owner_user_id,
        name="Live Room",
        subtitle=None,
        avatar_url=None,
        cover_photo_url=None,
        language="English",
        mode="Open",
        room_type="Chat",
        online_count=0,
        trending_score=0,
        is_active=True,
        is_secret=False,
        is_locked=False,
        is_members_only=False,
        allow_screenshots=True,
        background_theme_id="default",
        seat_layout_id="5x2",
    )
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def _default_room_settings_response(room_public_id: str) -> RoomSettingsResponse:
    return RoomSettingsResponse(
        room_public_id=room_public_id.strip(),
        name="Live Room",
        language="English",
        mode="Open",
        is_secret=False,
        is_locked=False,
        is_members_only=False,
        allow_screenshots=True,
        has_lock_password=False,
        background_theme_id="default",
        seat_layout_id="5x2",
        announcement_text=None,
        announcement_updated_at=None,
        announcement_updated_by_user_id=None,
    )


def _room_settings_response(room: Room) -> RoomSettingsResponse:
    return RoomSettingsResponse(
        room_public_id=room.room_public_id,
        name=room.name,
        language=room.language,
        mode=room.mode,
        is_secret=room.is_secret,
        is_locked=room.is_locked,
        is_members_only=room.is_members_only,
        allow_screenshots=room.allow_screenshots,
        has_lock_password=bool(room.lock_password_hash),
        background_theme_id=room.background_theme_id or "default",
        seat_layout_id=room.seat_layout_id or "5x2",
        announcement_text=room.announcement_text,
        announcement_updated_at=room.announcement_updated_at,
        announcement_updated_by_user_id=room.announcement_updated_by_user_id,
    )


def _room_discovery_payload(room: Room, *, online_count_override: int | None = None) -> dict:
    online_count = room.online_count if online_count_override is None else online_count_override
    return {
        "id": room.room_public_id,
        "room_public_id": room.room_public_id,
        "name": room.name,
        "subtitle": room.subtitle or "",
        "language": room.language,
        "mode": room.mode,
        "type": room.room_type,
        "room_type": room.room_type,
        "online_count": online_count,
        "trending_score": room.trending_score,
        "followed_friends_inside": [],
        "cover_photo_url": room.cover_photo_url or room.avatar_url,
        "avatar_url": room.avatar_url,
        "owner_user_id": room.owner_user_id,
        "is_active": room.is_active,
        "is_secret": room.is_secret,
        "is_locked": room.is_locked,
        "is_members_only": room.is_members_only,
        "allow_screenshots": room.allow_screenshots,
        "has_lock_password": bool(room.lock_password_hash),
        "seat_layout_id": room.seat_layout_id or "5x2",
    }


def _is_seed_or_test_room(room: Room) -> bool:
    name = (room.name or "").strip().lower()
    subtitle = (room.subtitle or "").strip().lower()
    public_id = (room.room_public_id or "").strip().lower()
    if name in {"test room", "demo room", "sample room", "seed room"}:
        return True
    if name.startswith("test ") or name.startswith("demo ") or name.startswith("seed "):
        return True
    if public_id.startswith(("test", "demo", "seed", "sample")):
        return True
    return any(marker in subtitle for marker in ("seed", "demo", "sample", "mock"))


def _clean_text(value: object, *, field_name: str, max_length: int, required: bool = True) -> str | None:
    text = value.strip() if isinstance(value, str) else ""
    if not text:
        if required:
            raise HTTPException(status_code=400, detail=f"{field_name} is required")
        return None
    if len(text) > max_length:
        raise HTTPException(status_code=400, detail=f"{field_name} is too long")
    return text


def _clean_numeric_lock_password(value: object, *, required: bool) -> str | None:
    text = value.strip() if isinstance(value, str) else ""
    if not text:
        if required:
            raise HTTPException(status_code=400, detail="4-digit room lock is required when locking room")
        return None
    if not text.isdigit():
        raise HTTPException(status_code=400, detail="Room lock must contain numbers only")
    if len(text) != 4:
        raise HTTPException(status_code=400, detail="Room lock must be exactly 4 digits")
    return text


def _new_room_public_id(db: Session) -> str:
    for _ in range(30):
        candidate = f"VM{random.randint(100000, 999999)}"
        exists = db.query(Room.id).filter(Room.room_public_id == candidate).first()
        if not exists:
            return candidate
    raise HTTPException(status_code=500, detail="Could not generate room ID")


def _apply_mode_flags(room: Room, mode: str) -> None:
    normalized = mode.strip().lower()
    room.mode = mode.strip() or "Open"
    room.is_secret = "secret" in normalized or "private" in normalized
    room.is_locked = "lock" in normalized
    room.is_members_only = "member" in normalized
    if not room.is_locked:
        room.lock_password_hash = None
        room.lock_updated_at = None
        room.lock_updated_by_user_id = None


def _find_lifetime_user_room(db: Session, user_id: int) -> Room | None:
    rooms = (
        db.query(Room)
        .filter(Room.owner_user_id == user_id)
        .order_by(Room.created_at.asc(), Room.id.asc())
        .limit(20)
        .all()
    )
    for room in rooms:
        if not _is_seed_or_test_room(room):
            return room
    return None


def _room_is_in_discovery_grace(room: Room) -> bool:
    now = datetime.utcnow()
    candidates = [getattr(room, "updated_at", None), getattr(room, "created_at", None)]
    for value in candidates:
        if value is None:
            continue
        try:
            if now - value <= timedelta(seconds=_NEW_ROOM_DISCOVERY_GRACE_SECONDS):
                return True
        except TypeError:
            continue
    return False


def _activate_room_for_discovery(room: Room) -> None:
    now = datetime.utcnow()
    room.is_active = True
    room.online_count = max(int(room.online_count or 0), 1)
    room.trending_score = max(int(room.trending_score or 0), 1)
    if hasattr(room, "updated_at"):
        room.updated_at = now


def _filter_discovery_rooms(
    db: Session,
    language: str | None,
    category: str | None,
    limit: int,
    include_locked: bool = False,
) -> list[tuple[Room, int]]:
    safe_limit = max(1, min(limit, 100))
    query = db.query(Room).filter(Room.is_active.is_(True), Room.is_secret.is_(False))
    if not include_locked:
        query = query.filter(Room.is_locked.is_(False), Room.is_members_only.is_(False))
    if language and language.strip() and language.strip().lower() != "all":
        query = query.filter(Room.language == language.strip())
    if category and category.strip() and category.strip().lower() != "all":
        query = query.filter(Room.room_type == category.strip())

    candidates = (
        query.order_by(Room.trending_score.desc(), Room.online_count.desc(), Room.updated_at.desc())
        .limit(min(max(safe_limit * 4, safe_limit), 300))
        .all()
    )

    visible_rooms: list[tuple[Room, int]] = []
    stale_rooms: list[Room] = []
    for room in candidates:
        active_count = _active_room_count(db, room.room_public_id)
        discovery_count = active_count
        if active_count <= 0 and _room_is_in_discovery_grace(room):
            discovery_count = max(int(room.online_count or 0), 1)
        if room.online_count != discovery_count:
            room.online_count = discovery_count
            stale_rooms.append(room)
        if discovery_count <= 0:
            continue
        visible_rooms.append((room, discovery_count))
        if len(visible_rooms) >= safe_limit:
            break

    if stale_rooms:
        for room in stale_rooms:
            db.add(room)
        db.commit()

    return visible_rooms


@router.get("/trending")
def get_trending_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[dict]:
    rooms = _filter_discovery_rooms(db=db, language=language, category=category, limit=limit, include_locked=False)
    return [_room_discovery_payload(room, online_count_override=active_count) for room, active_count in rooms]


@router.get("/following")
def get_following_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[dict]:
    rooms = _filter_discovery_rooms(db=db, language=language, category=category, limit=limit, include_locked=True)
    return [_room_discovery_payload(room, online_count_override=active_count) for room, active_count in rooms]


@router.post("")
def create_room(
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    name = _clean_text(payload.get("name"), field_name="Room name", max_length=120)
    language = _clean_text(payload.get("language"), field_name="Room language", max_length=40)
    mode = _clean_text(payload.get("mode") or "Open", field_name="Room mode", max_length=40)
    room_type = _clean_text(payload.get("room_type") or payload.get("type") or "Chat", field_name="Room type", max_length=40)
    subtitle = _clean_text(payload.get("subtitle"), field_name="Room subtitle", max_length=240, required=False)
    avatar_url = _clean_text(payload.get("avatar_url"), field_name="Room avatar", max_length=500, required=False)
    cover_photo_url = _clean_text(payload.get("cover_photo_url") or avatar_url, field_name="Room cover photo", max_length=500, required=False)
    allow_screenshots = payload.get("allow_screenshots")

    existing_room = _find_lifetime_user_room(db, current_user.id)
    if existing_room is not None:
        existing_room.name = name or existing_room.name
        existing_room.language = language or existing_room.language
        existing_room.room_type = room_type or existing_room.room_type
        existing_room.subtitle = subtitle if subtitle is not None else existing_room.subtitle
        if avatar_url is not None:
            existing_room.avatar_url = avatar_url
        if cover_photo_url is not None:
            existing_room.cover_photo_url = cover_photo_url
        if allow_screenshots is not None:
            existing_room.allow_screenshots = bool(allow_screenshots)
        _apply_mode_flags(existing_room, mode or existing_room.mode)
        if not existing_room.seat_layout_id:
            existing_room.seat_layout_id = "5x2"
        if existing_room.is_locked:
            lock_password = _clean_numeric_lock_password(payload.get("lock_password"), required=not bool(existing_room.lock_password_hash))
            if lock_password:
                existing_room.lock_password_hash = hash_password(lock_password)
                existing_room.lock_updated_at = datetime.utcnow()
                existing_room.lock_updated_by_user_id = current_user.id
        _activate_room_for_discovery(existing_room)
        db.add(existing_room)
        db.commit()
        db.refresh(existing_room)
        return _room_discovery_payload(existing_room)

    room = Room(
        room_public_id=_new_room_public_id(db),
        owner_user_id=current_user.id,
        name=name or "Live Room",
        subtitle=subtitle,
        avatar_url=avatar_url,
        cover_photo_url=cover_photo_url,
        language=language or "English",
        mode=mode or "Open",
        room_type=room_type or "Chat",
        online_count=1,
        trending_score=1,
        is_active=True,
        allow_screenshots=bool(allow_screenshots) if allow_screenshots is not None else True,
        seat_layout_id="5x2",
    )
    _apply_mode_flags(room, room.mode)
    if room.is_locked:
        lock_password = _clean_numeric_lock_password(payload.get("lock_password"), required=True)
        if lock_password:
            room.lock_password_hash = hash_password(lock_password)
            room.lock_updated_at = datetime.utcnow()
            room.lock_updated_by_user_id = current_user.id
    _activate_room_for_discovery(room)

    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_discovery_payload(room)


@router.get("/my-created-room")
def get_my_created_room(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict | None:
    room = _find_lifetime_user_room(db, current_user.id)
    if room is None:
        return None
    if not room.is_active:
        room.is_active = True
        db.add(room)
        db.commit()
        db.refresh(room)
    return _room_discovery_payload(room)


@router.get("/{room_public_id}/settings", response_model=RoomSettingsResponse)
def get_room_settings(room_public_id: str, db: Session = Depends(get_db)) -> RoomSettingsResponse:
    room = db.query(Room).filter(Room.room_public_id == room_public_id.strip()).first()
    if room is None:
        return _default_room_settings_response(room_public_id)
    return _room_settings_response(room)


@router.patch("/{room_public_id}/settings", response_model=RoomSettingsResponse)
def update_room_access_settings(
    room_public_id: str,
    payload: RoomAccessSettingsUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RoomSettingsResponse:
    room = _get_or_create_room_for_settings(db, room_public_id, current_user)
    if room.owner_user_id is not None and room.owner_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the room owner can update room settings")
    if room.owner_user_id is None:
        room.owner_user_id = current_user.id
    if payload.language is not None:
        room.language = payload.language.strip()
    if payload.allow_screenshots is not None:
        room.allow_screenshots = payload.allow_screenshots
    if payload.mode is not None:
        _apply_mode_flags(room, payload.mode)
        if room.is_locked:
            lock_password = _clean_numeric_lock_password(payload.lock_password, required=not bool(room.lock_password_hash))
            if lock_password:
                room.lock_password_hash = hash_password(lock_password)
                room.lock_updated_at = datetime.utcnow()
                room.lock_updated_by_user_id = current_user.id
    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_settings_response(room)


@router.patch("/{room_public_id}/mode")
def update_room_mode(
    room_public_id: str,
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    room = _get_room_by_public_id(db, room_public_id)
    if room.owner_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the room owner can update room mode")
    mode = _clean_text(payload.get("mode"), field_name="Room mode", max_length=40)
    _apply_mode_flags(room, mode or "Open")
    if room.is_locked:
        lock_password = _clean_numeric_lock_password(payload.get("lock_password"), required=not bool(room.lock_password_hash))
        if lock_password:
            room.lock_password_hash = hash_password(lock_password)
            room.lock_updated_at = datetime.utcnow()
            room.lock_updated_by_user_id = current_user.id
    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_discovery_payload(room)


@router.patch("/{room_public_id}/background", response_model=RoomSettingsResponse)
def update_room_background(
    room_public_id: str,
    payload: RoomBackgroundUpdateRequest,
    db: Session = Depends(get_db),
) -> RoomSettingsResponse:
    room = _get_or_create_room_for_settings(db, room_public_id)
    room.background_theme_id = payload.background_theme_id.strip() or "default"
    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_settings_response(room)


@router.patch("/{room_public_id}/seat-layout", response_model=RoomSettingsResponse)
def update_room_seat_layout(
    room_public_id: str,
    payload: RoomSeatLayoutUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RoomSettingsResponse:
    room = _get_or_create_room_for_settings(db, room_public_id, current_user)
    if room.owner_user_id is not None and room.owner_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the room owner can change seat layout")
    if room.owner_user_id is None:
        room.owner_user_id = current_user.id
    room.seat_layout_id = _clean_seat_layout_id(payload.seat_layout_id)
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
    room = _get_or_create_room_for_settings(db, room_public_id)
    text = payload.announcement_text.strip()
    room.announcement_text = text if text else None
    room.announcement_updated_at = datetime.utcnow()
    room.announcement_updated_by_user_id = room.owner_user_id
    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_settings_response(room)
