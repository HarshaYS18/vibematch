import random
from datetime import datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models.follow import UserFollow
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.schemas.rooms.room import RoomCreateRequest, RoomDetailResponse, RoomJoinResponse, RoomLeaveResponse, RoomParticipantUserResponse, RoomParticipantsResponse, RoomTrendingResponse
from app.services import economy_level_service, profile_service
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import get_primary_role, get_user_roles

# Backend truth: a user is considered inside a room only while room heartbeat is fresh.
# After 10 minutes without room heartbeat, backend closes the active participant row.
_ACTIVE_PARTICIPANT_WINDOW = timedelta(minutes=10)
_UNLIMITED_ROOM_ROLES = {"founder_owner", "owner"}


def _room_public_id_exists(db: Session, room_public_id: str) -> bool:
    return db.query(Room.id).filter(Room.room_public_id == room_public_id).first() is not None


def _role_values(user: User) -> set[str]:
    values: set[str] = set()
    for role in get_user_roles(user):
        values.add(role.value if hasattr(role, "value") else str(role))
    return values


def _can_create_unlimited_rooms(user: User) -> bool:
    return bool(_role_values(user) & _UNLIMITED_ROOM_ROLES)


def _existing_participant(db: Session, room: Room, user: User) -> RoomParticipant | None:
    return db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id).first()


def _can_manage_room(room: Room, user: User) -> bool:
    if room.owner_user_id == user.id or bool(_role_values(user) & _UNLIMITED_ROOM_ROLES):
        return True
    participant = _existing_participant(db=None, room=room, user=user) if False else None
    return False


def _can_manage_room_db(db: Session, room: Room, user: User) -> bool:
    if room.owner_user_id == user.id or bool(_role_values(user) & _UNLIMITED_ROOM_ROLES):
        return True
    participant = _existing_participant(db, room, user)
    return bool(participant and participant.is_room_admin)


def _normalize_mode(value: str | None) -> str:
    raw = (value or "Open").strip().lower()
    if raw in {"locked", "lock"}:
        return "Locked"
    if raw in {"members only", "member only", "members_only", "member", "members"}:
        return "Members Only"
    if raw in {"secret vibe", "private vibe", "secret", "private_vibe", "private"}:
        return "Secret Vibe"
    return "Open"


def _clean_lock_password(value: str | None) -> str | None:
    text = (value or "").strip()
    return text or None


def _clean_room_lock_password(value: str | None, *, required: bool) -> str | None:
    text = _clean_lock_password(value)
    if text is None:
        if required:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="4-digit room lock password is required when locking room.",
            )
        return None
    if not text.isdigit() or len(text) != 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Room lock password must be exactly 4 digits.",
        )
    return text


def _set_room_lock_password(room: Room, lock_password: str | None, actor_user_id: int | None) -> None:
    clean_password = _clean_room_lock_password(lock_password, required=True)
    room.lock_password_hash = hash_password(clean_password)
    room.lock_updated_at = datetime.utcnow()
    room.lock_updated_by_user_id = actor_user_id


def _clear_room_lock_password(room: Room) -> None:
    room.lock_password_hash = None
    room.lock_updated_at = None
    room.lock_updated_by_user_id = None


def _lock_password_matches(room: Room, lock_password: str | None) -> bool:
    clean_password = _clean_room_lock_password(lock_password, required=False)
    stored_hash = (room.lock_password_hash or "").strip()
    if clean_password is None or not stored_hash:
        return False
    try:
        return verify_password(clean_password, stored_hash)
    except Exception:
        return False


def apply_room_mode(room: Room, *, mode: str, actor_user_id: int | None = None, lock_password: str | None = None) -> Room:
    normalized = _normalize_mode(mode)
    room.mode = normalized
    room.is_secret = normalized == "Secret Vibe"
    room.is_locked = normalized == "Locked"
    room.is_members_only = normalized == "Members Only"

    if normalized == "Locked":
        _set_room_lock_password(room, lock_password, actor_user_id)
    else:
        _clear_room_lock_password(room)

    room.updated_at = datetime.utcnow()
    return room


def _apply_room_payload(room: Room, payload: RoomCreateRequest) -> Room:
    mode = _normalize_mode(payload.mode)
    room_type = payload.type.strip() or "Chat"
    room.name = payload.name.strip()
    room.subtitle = payload.subtitle.strip() if payload.subtitle else None
    if payload.avatar_url and payload.avatar_url.strip():
        room.avatar_url = payload.avatar_url.strip()
    if payload.cover_photo_url and payload.cover_photo_url.strip():
        room.cover_photo_url = payload.cover_photo_url.strip()
    elif payload.avatar_url and payload.avatar_url.strip():
        room.cover_photo_url = payload.avatar_url.strip()
    room.language = payload.language.strip() or "English"
    room.room_type = room_type
    apply_room_mode(room, mode=mode, actor_user_id=room.owner_user_id, lock_password=payload.lock_password)
    room.is_active = True
    room.updated_at = datetime.utcnow()
    return room


def _upsert_active_participant(db: Session, room: Room, user: User) -> RoomParticipant:
    now = datetime.utcnow()
    participant = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id).first()
    if participant is None:
        participant = RoomParticipant(room_id=room.id, user_id=user.id, is_active=True, joined_at=now, last_seen_at=now)
        db.add(participant)
    else:
        participant.is_active = True
        participant.last_seen_at = now
        participant.left_at = None
    if room.owner_user_id == user.id:
        participant.is_member = True
        participant.is_room_admin = True
        participant.member_added_at = participant.member_added_at or now
        participant.admin_added_at = participant.admin_added_at or now
    user.last_seen_at = now
    return participant


def _upsert_saved_participant(db: Session, room: Room, user: User, *, is_member: bool = False, is_room_admin: bool = False, active: bool = False) -> RoomParticipant:
    now = datetime.utcnow()
    participant = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id).first()
    if participant is None:
        participant = RoomParticipant(room_id=room.id, user_id=user.id, is_active=active, joined_at=now, last_seen_at=user.last_seen_at or now)
        db.add(participant)
    participant.is_member = participant.is_member or is_member
    participant.is_room_admin = participant.is_room_admin or is_room_admin
    if is_member:
        participant.member_added_at = participant.member_added_at or now
    if is_room_admin:
        participant.admin_added_at = participant.admin_added_at or now
    return participant


def _can_enter_room(db: Session, room: Room, user: User, lock_password: str | None = None) -> bool:
    # Host, official Owner/Super Owner, and approved chatroom admins can enter without lock/password.
    if _can_manage_room_db(db, room, user):
        return True
    participant = _existing_participant(db, room, user)
    approved = participant is not None and (participant.is_member or participant.is_room_admin)
    if approved:
        return True
    if room.is_secret or room.is_members_only:
        return False
    if room.is_locked:
        return _lock_password_matches(room, lock_password)
    # Open rooms allow visitors to enter, but they are not chatroom members until approved.
    return True


def _to_user_response(user: User, participant: RoomParticipant | None = None) -> RoomParticipantUserResponse:
    stats = economy_level_service.get_user_economy_summary(user)
    badges = get_role_badges(user)
    primary_badge = get_primary_role_badge(user)
    return RoomParticipantUserResponse(
        user_id=user.id,
        public_user_id=user.public_user_id,
        display_name=user.display_name or user.username or f"User {user.public_user_id}",
        username=user.username,
        avatar_url=user.avatar_url,
        vip_level=stats.vip_level,
        svip_level=stats.svip_level,
        send_level=stats.send_level,
        receive_level=stats.receive_level,
        primary_role=get_primary_role(user),
        role_badges=badges,
        primary_role_badge=primary_badge,
        family_name=profile_service.get_family_name(user),
        family_level=profile_service.get_family_level(user),
        is_member=bool(participant.is_member) if participant else False,
        is_room_admin=bool(participant.is_room_admin) if participant else False,
        is_active=bool(participant.is_active) if participant else False,
        joined_at=participant.joined_at if participant else None,
        last_seen_at=participant.last_seen_at if participant else None,
    )


def _room_avatar_gradient(room_public_id: str) -> list[str]:
    palettes = [
        ["#12C7B7", "#6D5DF6"],
        ["#FF8AB3", "#FFC857"],
        ["#6D5DF6", "#E84C72"],
        ["#12C7B7", "#C99A3B"],
        ["#8C5CF6", "#12C7B7"],
    ]
    return palettes[sum(ord(ch) for ch in room_public_id) % len(palettes)]


def _to_detail_response(room: Room, participants: list[RoomParticipant] | None = None) -> RoomDetailResponse:
    active_participants = [item for item in participants or [] if item.is_active]
    user_responses = [_to_user_response(item.user, item) for item in active_participants if item.user is not None]
    return RoomDetailResponse(
        room_public_id=room.room_public_id,
        name=room.name,
        subtitle=room.subtitle,
        language=room.language,
        type=room.room_type,
        mode=room.mode,
        online_count=len(active_participants) if participants is not None else room.online_count,
        trending_score=room.trending_score,
        avatar_url=room.avatar_url,
        cover_photo_url=room.cover_photo_url,
        avatar_gradient=_room_avatar_gradient(room.room_public_id),
        followed_friends_inside=[],
        owner_public_user_id=room.owner.public_user_id if room.owner is not None else None,
        owner_user_id=room.owner_user_id,
        is_secret=room.is_secret,
        is_locked=room.is_locked,
        is_members_only=room.is_members_only,
        allow_screenshots=room.allow_screenshots,
        has_lock_password=bool(room.lock_password_hash),
        participants=user_responses,
    )


def _trending_response(room: Room) -> RoomTrendingResponse:
    return RoomTrendingResponse(
        room_public_id=room.room_public_id,
        name=room.name,
        subtitle=room.subtitle,
        language=room.language,
        type=room.room_type,
        mode=room.mode,
        online_count=room.online_count,
        trending_score=room.trending_score,
        avatar_url=room.avatar_url,
        cover_photo_url=room.cover_photo_url,
        avatar_gradient=_room_avatar_gradient(room.room_public_id),
        followed_friends_inside=[],
        owner_public_user_id=room.owner.public_user_id if room.owner is not None else None,
        owner_user_id=room.owner_user_id,
        is_secret=room.is_secret,
        is_locked=room.is_locked,
        is_members_only=room.is_members_only,
        allow_screenshots=room.allow_screenshots,
        has_lock_password=bool(room.lock_password_hash),
    )


def _update_room_counts(room: Room, active_count: int | None = None) -> None:
    if active_count is None:
        active_count = sum(1 for item in room.participants if item.is_active)
    room.online_count = active_count
    room.trending_score = active_count * 10
    room.updated_at = datetime.utcnow()


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


def _find_lifetime_user_room(db: Session, user_id: int) -> Room | None:
    rooms = db.query(Room).filter(Room.owner_user_id == user_id).order_by(Room.created_at.asc(), Room.id.asc()).limit(20).all()
    for room in rooms:
        if not _is_seed_or_test_room(room):
            return room
    return None


def create_room(db: Session, current_user: User, payload: RoomCreateRequest) -> RoomDetailResponse:
    if not _can_create_unlimited_rooms(current_user):
        existing_room = _find_lifetime_user_room(db, current_user.id)
        if existing_room is not None:
            _apply_room_payload(existing_room, payload)
            participant = _upsert_saved_participant(db, existing_room, current_user, is_member=True, is_room_admin=True, active=False)
            db.add(existing_room)
            db.add(participant)
            db.commit()
            db.refresh(existing_room)
            return _to_detail_response(existing_room, [participant])

    room_public_id = _generate_room_public_id(db)
    room = Room(
        room_public_id=room_public_id,
        owner_user_id=current_user.id,
        name=payload.name.strip(),
        subtitle=payload.subtitle.strip() if payload.subtitle else None,
        avatar_url=payload.avatar_url.strip() if payload.avatar_url else None,
        cover_photo_url=payload.cover_photo_url.strip() if payload.cover_photo_url else None,
        language=payload.language.strip() or "English",
        room_type=payload.type.strip() or "Chat",
        online_count=0,
        trending_score=0,
        is_active=True,
    )
    mode = _normalize_mode(payload.mode)
    apply_room_mode(room, mode=mode, actor_user_id=current_user.id, lock_password=payload.lock_password)
    db.add(room)
    db.flush()
    participant = _upsert_saved_participant(db, room, current_user, is_member=True, is_room_admin=True, active=False)
    db.add(participant)
    db.commit()
    db.refresh(room)
    return _to_detail_response(room, [participant])
