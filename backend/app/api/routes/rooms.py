import random
from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.core.security import hash_password
from app.database import get_db
from app.models.room import Room
from app.models.user import User
from app.schemas.room_settings import (
    RoomAnnouncementUpdateRequest,
    RoomBackgroundUpdateRequest,
    RoomSettingsResponse,
)

router = APIRouter(prefix="/rooms", tags=["rooms"])


def _get_room_by_public_id(db: Session, room_public_id: str) -> Room:
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
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


def _room_discovery_payload(room: Room) -> dict:
    return {
        "id": room.room_public_id,
        "room_public_id": room.room_public_id,
        "name": room.name,
        "subtitle": room.subtitle or "",
        "language": room.language,
        "mode": room.mode,
        "type": room.room_type,
        "room_type": room.room_type,
        "online_count": room.online_count,
        "trending_score": room.trending_score,
        "followed_friends_inside": [],
        "cover_photo_url": room.cover_photo_url or room.avatar_url,
        "avatar_url": room.avatar_url,
        "owner_user_id": room.owner_user_id,
        "is_active": room.is_active,
        "is_secret": room.is_secret,
        "is_locked": room.is_locked,
        "is_members_only": room.is_members_only,
        "has_lock_password": bool(room.lock_password_hash),
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


def _new_room_public_id(db: Session) -> str:
    for _ in range(30):
        candidate = f"VM{random.randint(100000, 999999)}"
        exists = db.query(Room.id).filter(Room.room_public_id == candidate).first()
        if not exists:
            return candidate
    raise HTTPException(status_code=500, detail="Could not generate room ID")


def _apply_mode_flags(room: Room, mode: str) -> None:
    normalized = mode.strip().lower()
    room.is_secret = "secret" in normalized
    room.is_locked = "lock" in normalized
    room.is_members_only = "member" in normalized


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


def _filter_discovery_rooms(
    db: Session,
    language: str | None,
    category: str | None,
    limit: int,
    include_locked: bool = False,
) -> list[Room]:
    query = db.query(Room).filter(Room.is_active.is_(True), Room.is_secret.is_(False))
    if not include_locked:
        query = query.filter(Room.is_locked.is_(False), Room.is_members_only.is_(False))
    if language and language.strip() and language.strip().lower() != "all":
        query = query.filter(Room.language == language.strip())
    if category and category.strip() and category.strip().lower() != "all":
        query = query.filter(Room.room_type == category.strip())
    return query.order_by(Room.trending_score.desc(), Room.online_count.desc(), Room.updated_at.desc()).limit(max(1, min(limit, 100))).all()


@router.get("/trending")
def get_trending_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[dict]:
    rooms = _filter_discovery_rooms(db=db, language=language, category=category, limit=limit, include_locked=False)
    return [_room_discovery_payload(room) for room in rooms]


@router.get("/following")
def get_following_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[dict]:
    rooms = _filter_discovery_rooms(db=db, language=language, category=category, limit=limit, include_locked=True)
    return [_room_discovery_payload(room) for room in rooms]


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
    lock_password = _clean_text(payload.get("lock_password"), field_name="Lock password", max_length=80, required=False)

    existing_room = _find_lifetime_user_room(db, current_user.id)
    if existing_room is not None:
        existing_room.name = name or existing_room.name
        if avatar_url is not None:
            existing_room.avatar_url = avatar_url
        if cover_photo_url is not None:
            existing_room.cover_photo_url = cover_photo_url
        existing_room.is_active = True
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
        trending_score=0,
        is_active=True,
    )
    _apply_mode_flags(room, room.mode)
    if room.is_locked and lock_password:
        room.lock_password_hash = hash_password(lock_password)
        room.lock_updated_at = datetime.utcnow()
        room.lock_updated_by_user_id = current_user.id

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
    room.announcement_updated_by_user_id = room.owner_user_id
    db.add(room)
    db.commit()
    db.refresh(room)
    return _room_settings_response(room)
