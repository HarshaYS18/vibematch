import random
from datetime import datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models.follow import UserFollow
from app.models.presence import UserRoomPresence
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomSeatState
from app.models.user import User
from app.schemas.rooms.room import RoomCreateRequest, RoomDetailResponse, RoomJoinResponse, RoomLeaveResponse, RoomParticipantUserResponse, RoomParticipantsResponse, RoomTrendingResponse
from app.services import economy_level_service, profile_service
from app.services.permissions import room_permission_service
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import get_primary_role, get_user_roles
from app.services.rooms.room_kickout_service import active_kickout_for_user

# Backend truth: a user is considered inside a room only while room heartbeat is fresh.
# After 5 minutes without room heartbeat, backend closes the active participant row.
_ACTIVE_PARTICIPANT_WINDOW = timedelta(minutes=5)
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


def _is_seed_or_test_room(room: Room) -> bool:
    name = (room.name or "").strip().lower()
    subtitle = (room.subtitle or "").strip().lower()
    public_id = (room.room_public_id or "").strip().lower()
    if name in {"test room", "demo room", "sample room", "seed room"}:
        return True
    if name.startswith(("test ", "demo ", "seed ", "sample ")):
        return True
    if public_id.startswith(("test", "demo", "seed", "sample")):
        return True
    return any(marker in subtitle for marker in ("seed", "demo", "sample", "mock"))


def _find_user_created_room(db: Session, user_id: int, *, active_only: bool) -> Room | None:
    query = db.query(Room).filter(Room.owner_user_id == user_id)
    if active_only:
        query = query.filter(Room.is_active.is_(True))

    rooms = (
        query.order_by(Room.updated_at.desc(), Room.created_at.desc(), Room.id.desc())
        .limit(50)
        .all()
    )
    for room in rooms:
        if not _is_seed_or_test_room(room):
            return room
    return None


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
    clean_password = _clean_room_lock_password(lock_password, required=not bool(room.lock_password_hash))
    if clean_password is None:
        return
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


def _active_kickout_detail(db: Session, room: Room, user: User) -> str | None:
    kickout = active_kickout_for_user(db, room_public_id=room.room_public_id, user=user)
    if kickout is None:
        return None
    if kickout.is_permanent:
        return "You are currently kicked from this room permanently. You can message the host/admin if you believe this was a mistake."
    if kickout.blocked_until is not None:
        remaining = kickout.blocked_until - datetime.utcnow()
        total_seconds = max(0, int(remaining.total_seconds()))
        if total_seconds >= 86400:
            duration = f"{(total_seconds + 86399) // 86400} day(s)"
        elif total_seconds >= 3600:
            duration = f"{(total_seconds + 3599) // 3600} hour(s)"
        else:
            duration = f"{max(1, (total_seconds + 59) // 60)} minute(s)"
        return f"You are currently kicked from this room for about {duration}. Re-entry opens at {kickout.blocked_until.isoformat()} UTC. Take a breather and come back fresh, or message the host/admin if this feels off."
    return "You are currently kicked from this room. Message the host/admin if you believe this was a mistake."


def _can_enter_room(db: Session, room: Room, user: User, lock_password: str | None = None) -> bool:
    if active_kickout_for_user(db, room_public_id=room.room_public_id, user=user) is not None:
        return False
    if _can_manage_room_db(db, room, user):
        return True
    if room_permission_service.can_force_join_room(db, user):
        return True
    participant = _existing_participant(db, room, user)
    approved = participant is not None and (participant.is_member or participant.is_room_admin)
    if approved:
        return True
    if room.is_secret:
        return room_permission_service.can_override_secret_room(db, user)
    if room.is_members_only:
        return False
    if room.is_locked:
        if participant is not None and participant.is_active:
            return True
        return room_permission_service.can_override_locked_room(db, user) or _lock_password_matches(room, lock_password)
    return True


def _room_access_denied_message(db: Session, room: Room, user: User, *, lock_password: str | None = None) -> str:
    kickout_detail = _active_kickout_detail(db, room, user)
    if kickout_detail is not None:
        return kickout_detail
    if room.is_secret:
        return "This Secret Vibe room is invite-only."
    if room.is_members_only:
        return "This room is members-only. Ask the channel host/admin for approval."
    if room.is_locked:
        if _clean_lock_password(lock_password) is None:
            return "This room is locked. Enter the room lock or use an invite from the channel owner/admin."
        return "Incorrect room lock. Try again or ask the channel owner/admin for an invite."
    return "Room not found or not accessible"


def assert_room_entry_allowed(db: Session, room: Room, user: User, lock_password: str | None = None) -> None:
    if not _can_enter_room(db, room, user, lock_password=lock_password):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_room_access_denied_message(db, room, user, lock_password=lock_password),
        )


def _get_room_or_404(db: Session, room_public_id: str) -> Room:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    return room


def _get_user_or_404(db: Session, public_user_id: int) -> User:
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def generate_room_public_id(db: Session) -> str:
    for _ in range(20):
        room_public_id = f"VM{random.randint(100000, 999999)}"
        if not _room_public_id_exists(db, room_public_id):
            return room_public_id
    raise RuntimeError("Could not generate unique room ID")


def _expire_stale_room_presence(db: Session, *, room_public_id: str | None = None, now: datetime | None = None) -> int:
    now = now or datetime.utcnow()
    cutoff = now - _ACTIVE_PARTICIPANT_WINDOW
    query = db.query(UserRoomPresence).filter(
        UserRoomPresence.is_active.is_(True),
        UserRoomPresence.last_heartbeat_at < cutoff,
    )
    if room_public_id is not None:
        query = query.filter(UserRoomPresence.room_public_id == room_public_id)
    return int(
        query.update(
            {UserRoomPresence.is_active: False, UserRoomPresence.left_at: now},
            synchronize_session=False,
        )
        or 0
    )


def _active_room_user_ids(db: Session, room: Room, cutoff: datetime) -> set[int]:
    participant_ids = {
        row[0]
        for row in db.query(RoomParticipant.user_id)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.is_active.is_(True),
            RoomParticipant.visible_in_online_count.is_(True),
            RoomParticipant.last_seen_at >= cutoff,
        )
        .all()
    }
    return participant_ids


def _refresh_room_online_count(db: Session, room: Room) -> int:
    now = datetime.utcnow()
    cutoff = now - _ACTIVE_PARTICIPANT_WINDOW
    db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True), RoomParticipant.last_seen_at < cutoff).update({RoomParticipant.is_active: False, RoomParticipant.left_at: now}, synchronize_session=False)
    _expire_stale_room_presence(db, room_public_id=room.room_public_id, now=now)
    count = len(_active_room_user_ids(db, room, cutoff))
    room.online_count = count
    room.trending_score = max(int(room.trending_score or 0), count)
    db.flush()
    return count


def deactivate_user_in_room(
    db: Session,
    room: Room,
    user_id: int,
    *,
    release_seats: bool = True,
    now: datetime | None = None,
) -> None:
    now = now or datetime.utcnow()
    participant = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user_id).first()
    if participant is not None:
        participant.is_active = False
        participant.left_at = now
        participant.last_seen_at = now
    db.query(UserRoomPresence).filter(
        UserRoomPresence.room_public_id == room.room_public_id,
        UserRoomPresence.user_id == user_id,
        UserRoomPresence.is_active.is_(True),
    ).update(
        {UserRoomPresence.is_active: False, UserRoomPresence.left_at: now, UserRoomPresence.last_heartbeat_at: now},
        synchronize_session=False,
    )
    if release_seats:
        for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id == user_id).all():
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.left_at = now
            seat.updated_by_user_id = user_id
    _refresh_room_online_count(db, room)
    db.flush()


def close_other_active_room_sessions(db: Session, user_id: int, except_room_public_id: str | None = None) -> set[str]:
    now = datetime.utcnow()
    changed_room_ids: set[str] = set()
    room_ids: set[int] = set()

    active_participants = (
        db.query(RoomParticipant)
        .join(Room, Room.id == RoomParticipant.room_id)
        .filter(RoomParticipant.user_id == user_id, RoomParticipant.is_active.is_(True))
        .all()
    )
    for participant in active_participants:
        room = participant.room
        if room is None:
            continue
        if except_room_public_id is not None and room.room_public_id == except_room_public_id:
            continue
        participant.is_active = False
        participant.left_at = now
        participant.last_seen_at = now
        changed_room_ids.add(room.room_public_id)
        room_ids.add(room.id)

    active_presence = (
        db.query(UserRoomPresence)
        .filter(UserRoomPresence.user_id == user_id, UserRoomPresence.is_active.is_(True))
        .all()
    )
    for presence in active_presence:
        if except_room_public_id is not None and presence.room_public_id == except_room_public_id:
            continue
        presence.is_active = False
        presence.left_at = now
        presence.last_heartbeat_at = now
        changed_room_ids.add(presence.room_public_id)

    if room_ids:
        for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id.in_(room_ids), RoomSeatState.occupant_user_id == user_id).all():
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.left_at = now
            seat.updated_by_user_id = user_id

    for room_public_id in changed_room_ids:
        room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
        if room is not None:
            _refresh_room_online_count(db, room)

    db.flush()
    return changed_room_ids


def user_has_active_room_conflict(db: Session, user_id: int, room_public_id: str) -> bool:
    cutoff = datetime.utcnow() - _ACTIVE_PARTICIPANT_WINDOW
    active_participant = (
        db.query(RoomParticipant.id)
        .join(Room, Room.id == RoomParticipant.room_id)
        .filter(
            RoomParticipant.user_id == user_id,
            RoomParticipant.is_active.is_(True),
            RoomParticipant.last_seen_at >= cutoff,
            Room.room_public_id != room_public_id,
        )
        .first()
    )
    if active_participant is not None:
        return True
    active_presence = (
        db.query(UserRoomPresence.id)
        .filter(
            UserRoomPresence.user_id == user_id,
            UserRoomPresence.is_active.is_(True),
            UserRoomPresence.last_heartbeat_at >= cutoff,
            UserRoomPresence.room_public_id != room_public_id,
        )
        .first()
    )
    return active_presence is not None


def mark_user_room_presence_active(db: Session, room: Room, user: User) -> None:
    now = datetime.utcnow()
    presence = (
        db.query(UserRoomPresence)
        .filter(
            UserRoomPresence.user_id == user.id,
            UserRoomPresence.room_public_id == room.room_public_id,
            UserRoomPresence.is_active.is_(True),
        )
        .first()
    )
    if presence is None:
        presence = UserRoomPresence(
            user_id=user.id,
            room_public_id=room.room_public_id,
            room_name=room.name or "Live Room",
            room_mode=room.mode,
            is_secret=bool(room.is_secret),
            is_active=True,
            entered_at=now,
            last_heartbeat_at=now,
        )
        db.add(presence)
    else:
        presence.room_name = room.name or presence.room_name
        presence.room_mode = room.mode
        presence.is_secret = bool(room.is_secret)
        presence.last_heartbeat_at = now
        presence.left_at = None
    db.flush()


def cleanup_stale_room_participants(db: Session) -> int:
    now = datetime.utcnow()
    cutoff = now - _ACTIVE_PARTICIPANT_WINDOW
    updated = db.query(RoomParticipant).filter(RoomParticipant.is_active.is_(True), RoomParticipant.last_seen_at < cutoff).update({RoomParticipant.is_active: False, RoomParticipant.left_at: now}, synchronize_session=False)
    presence_updated = _expire_stale_room_presence(db, now=now)
    rooms = db.query(Room).filter(Room.is_active.is_(True)).all()
    for room in rooms:
        _refresh_room_online_count(db, room)
    db.commit()
    return int(updated or 0) + int(presence_updated or 0)


def room_to_trending_response(room: Room, followed_friends_inside: list[str] | None = None) -> RoomTrendingResponse:
    return RoomTrendingResponse(id=room.room_public_id, name=room.name, subtitle=room.subtitle, avatar_url=room.avatar_url, cover_photo_url=room.cover_photo_url or room.avatar_url, language=room.language, mode=room.mode, type=room.room_type, online_count=room.online_count, trending_score=room.trending_score, followed_friends_inside=followed_friends_inside or [])


def room_to_detail_response(room: Room) -> RoomDetailResponse:
    return RoomDetailResponse(id=room.room_public_id, name=room.name, subtitle=room.subtitle, avatar_url=room.avatar_url, cover_photo_url=room.cover_photo_url or room.avatar_url, language=room.language, mode=room.mode, type=room.room_type, online_count=room.online_count, trending_score=room.trending_score, followed_friends_inside=[], owner_user_id=room.owner_user_id, is_active=room.is_active, is_secret=room.is_secret, is_locked=room.is_locked, is_members_only=room.is_members_only, has_lock_password=bool((room.lock_password_hash or '').strip()))


def participant_to_response(db: Session, participant: RoomParticipant, room: Room) -> RoomParticipantUserResponse:
    user = participant.user
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
    levels = economy_level_service.user_level_payload(db, user.id)
    is_online = bool(participant.is_active)
    is_owner = room.owner_user_id == user.id
    is_admin = participant.is_room_admin or is_owner
    is_member = participant.is_member or is_admin
    section = "owner" if is_owner else ("admin" if is_admin else ("member" if is_member else "visitor"))
    return RoomParticipantUserResponse(
        public_user_id=user.public_user_id,
        display_custom_id=user.display_custom_id,
        username=user.username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        primary_role=primary_role.value,
        primary_role_badge=get_primary_role_badge(primary_role),
        role_badges=get_role_badges(user_roles),
        vip=profile_service.vip_summary(db, user, levels),
        equipped_items=profile_service.equipped_items_summary(db, user),
        sending_level=int(levels["sent"].get("level") or 0),
        receiving_level=int(levels["received"].get("level") or 0),
        sent_exp=levels["monthly_gift_coins_sent"],
        received_exp=levels["monthly_gift_coins_received"],
        monthly_gift_coins_sent=levels["monthly_gift_coins_sent"],
        monthly_gift_coins_received=levels["monthly_gift_coins_received"],
        is_owner=is_owner,
        is_member=is_member,
        is_room_admin=is_admin,
        is_online=is_online,
        list_section=section,
        joined_at=participant.joined_at,
        last_seen_at=participant.last_seen_at,
    )


def _ensure_owner_participant(db: Session, room: Room) -> None:
    if room.owner_user_id is None:
        return
    owner = db.query(User).filter(User.id == room.owner_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if owner is None:
        return
    _upsert_saved_participant(db, room, owner, is_member=True, is_room_admin=True, active=False)


def roster_participants(db: Session, room: Room) -> list[RoomParticipant]:
    _refresh_room_online_count(db, room)
    _ensure_owner_participant(db, room)
    return db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, ((RoomParticipant.is_active.is_(True)) | (RoomParticipant.is_member.is_(True)) | (RoomParticipant.is_room_admin.is_(True)))).order_by(RoomParticipant.is_room_admin.desc(), RoomParticipant.is_member.desc(), RoomParticipant.is_active.desc(), RoomParticipant.joined_at.asc()).all()


def active_participants(db: Session, room: Room) -> list[RoomParticipant]:
    _refresh_room_online_count(db, room)
    cutoff = datetime.utcnow() - _ACTIVE_PARTICIPANT_WINDOW
    return db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True), RoomParticipant.last_seen_at >= cutoff).order_by(RoomParticipant.joined_at.asc()).all()


def create_room(db: Session, current_user: User, payload: RoomCreateRequest) -> RoomDetailResponse:
    if not _can_create_unlimited_rooms(current_user):
        existing_room = _find_user_created_room(db, current_user.id, active_only=False)
        if existing_room is not None:
            _apply_room_payload(existing_room, payload)
            _upsert_active_participant(db, existing_room, current_user)
            _refresh_room_online_count(db, existing_room)
            db.commit()
            db.refresh(existing_room)
            return room_to_detail_response(existing_room)

    mode = _normalize_mode(payload.mode)
    room_type = payload.type.strip() or "Chat"
    avatar_url = payload.avatar_url.strip() if payload.avatar_url else None
    cover_photo_url = payload.cover_photo_url.strip() if payload.cover_photo_url else avatar_url
    room = Room(room_public_id=generate_room_public_id(db), owner_user_id=current_user.id, name=payload.name.strip(), subtitle=payload.subtitle.strip() if payload.subtitle else None, avatar_url=avatar_url, cover_photo_url=cover_photo_url, language=payload.language.strip() or "English", room_type=room_type, online_count=0, trending_score=1, is_active=True)
    apply_room_mode(room, mode=mode, actor_user_id=current_user.id, lock_password=payload.lock_password)
    db.add(room)
    db.flush()
    _upsert_active_participant(db, room, current_user)
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(room)
    return room_to_detail_response(room)


def get_my_created_room(db: Session, current_user: User) -> RoomDetailResponse | None:
    room = _find_user_created_room(db, current_user.id, active_only=False)
    if room is None:
        return None
    room.is_active = True
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(room)
    return room_to_detail_response(room)


def get_room_model_by_public_id(db: Session, room_public_id: str) -> Room | None:
    return db.query(Room).filter(Room.room_public_id == room_public_id, Room.is_active.is_(True)).first()


def get_room_by_public_id(db: Session, room_public_id: str) -> RoomDetailResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        return None
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(room)
    return room_to_detail_response(room)


def join_room(db: Session, room_public_id: str, current_user: User, lock_password: str | None = None) -> RoomJoinResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        return None
    assert_room_entry_allowed(db, room, current_user, lock_password=lock_password)

    closed_room_ids = close_other_active_room_sessions(db, current_user.id, except_room_public_id=room.room_public_id)
    previous = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == current_user.id).first()
    was_active = previous.is_active if previous is not None else False
    participant = _upsert_active_participant(db, room, current_user)
    mark_user_room_presence_active(db, room, current_user)
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(room)
    db.refresh(participant)
    participants = roster_participants(db, room)
    db.commit()
    response = RoomJoinResponse(room=room_to_detail_response(room), participants=[participant_to_response(db, item, room) for item in participants], joined_user=participant_to_response(db, participant, room), should_show_entered_message=not was_active, closed_room_ids=sorted(closed_room_ids))
    # participant_to_response may create wallet, experience and VIP rows. Commit
    # those writes before the async route broadcasts, or a concurrent room join
    # can wait on this transaction while blocking the FastAPI event loop.
    db.commit()
    return response


def heartbeat_room(db: Session, room_public_id: str, current_user: User) -> RoomJoinResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        return None
    assert_room_entry_allowed(db, room, current_user)
    if user_has_active_room_conflict(db, current_user.id, room.room_public_id):
        deactivate_user_in_room(db, room, current_user.id)
        db.commit()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This account is already active in another chatroom")
    participant = _existing_participant(db, room, current_user)
    if participant is None or not participant.is_active:
        participant = _upsert_active_participant(db, room, current_user)
    else:
        participant.last_seen_at = datetime.utcnow()
        current_user.last_seen_at = participant.last_seen_at
    mark_user_room_presence_active(db, room, current_user)
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(room)
    participants = roster_participants(db, room)
    db.commit()
    response = RoomJoinResponse(room=room_to_detail_response(room), participants=[participant_to_response(db, item, room) for item in participants], joined_user=participant_to_response(db, participant, room), should_show_entered_message=False)
    db.commit()
    return response


def leave_room(db: Session, room_public_id: str, current_user: User) -> RoomLeaveResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        return None
    now = datetime.utcnow()
    deactivate_user_in_room(db, room, current_user.id, now=now)
    count = int(room.online_count or 0)
    db.commit()
    return RoomLeaveResponse(room_id=room.room_public_id, online_count=count, left=True)


def list_room_participants(db: Session, room_public_id: str, current_user: User) -> RoomParticipantsResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room or not _can_enter_room(db, room, current_user):
        return None
    participants = roster_participants(db, room)
    db.commit()
    response = RoomParticipantsResponse(room_id=room.room_public_id, online_count=room.online_count, participants=[participant_to_response(db, participant, room) for participant in participants])
    db.commit()
    return response


def list_trending_rooms(db: Session, language: str | None = None, category: str | None = None, limit: int = 30) -> list[RoomTrendingResponse]:
    cleanup_stale_room_participants(db)
    query = db.query(Room).filter(Room.is_active.is_(True), Room.is_secret.is_(False), Room.is_locked.is_(False), Room.is_members_only.is_(False), Room.online_count > 0)
    if language and language.lower() != "all":
        query = query.filter(Room.language.ilike(language))
    if category and category.lower() not in {"all", "trending"}:
        query = query.filter(Room.room_type.ilike(category))
    rooms = query.order_by(Room.trending_score.desc(), Room.online_count.desc(), Room.updated_at.desc()).limit(limit).all()
    return [room_to_trending_response(room) for room in rooms]


def list_following_rooms(db: Session, current_user: User, language: str | None = None, category: str | None = None, limit: int = 30) -> list[RoomTrendingResponse]:
    cleanup_stale_room_participants(db)
    followed_ids = [row[0] for row in db.query(UserFollow.followed_user_id).filter(UserFollow.follower_user_id == current_user.id).all()]
    if not followed_ids:
        return []
    cutoff = datetime.utcnow() - _ACTIVE_PARTICIPANT_WINDOW
    room_ids = {
        row[0]
        for row in db.query(RoomParticipant.room_id)
        .filter(
            RoomParticipant.user_id.in_(followed_ids),
            RoomParticipant.is_active.is_(True),
            RoomParticipant.last_seen_at >= cutoff,
        )
        .distinct()
        .all()
    }
    room_public_ids = [
        row[0]
        for row in db.query(UserRoomPresence.room_public_id)
        .filter(
            UserRoomPresence.user_id.in_(followed_ids),
            UserRoomPresence.is_active.is_(True),
            UserRoomPresence.last_heartbeat_at >= cutoff,
        )
        .distinct()
        .all()
    ]
    if room_public_ids:
        room_ids.update(
            row[0]
            for row in db.query(Room.id)
            .filter(Room.room_public_id.in_(room_public_ids))
            .all()
        )
    if not room_ids:
        return []
    query = db.query(Room).filter(Room.id.in_(room_ids), Room.is_active.is_(True), Room.is_secret.is_(False), Room.online_count > 0)
    if language and language.lower() != "all":
        query = query.filter(Room.language.ilike(language))
    if category and category.lower() not in {"all", "trending"}:
        query = query.filter(Room.room_type.ilike(category))
    rooms = query.order_by(Room.online_count.desc(), Room.updated_at.desc()).limit(limit).all()
    result: list[RoomTrendingResponse] = []
    for room in rooms:
        names = [row[0] for row in db.query(User.display_name).join(RoomParticipant, RoomParticipant.user_id == User.id).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id.in_(followed_ids), RoomParticipant.is_active.is_(True)).limit(3).all()]
        if len(names) < 3:
            names.extend(
                row[0]
                for row in db.query(User.display_name)
                .join(UserRoomPresence, UserRoomPresence.user_id == User.id)
                .filter(
                    UserRoomPresence.room_public_id == room.room_public_id,
                    UserRoomPresence.user_id.in_(followed_ids),
                    UserRoomPresence.is_active.is_(True),
                    UserRoomPresence.last_heartbeat_at >= cutoff,
                )
                .limit(3 - len(names))
                .all()
            )
        result.append(room_to_trending_response(room, list(dict.fromkeys(name for name in names if name))[:3]))
    return result


def set_room_member(db: Session, room_public_id: str, current_user: User, target_public_user_id: int, is_member: bool) -> RoomParticipantUserResponse:
    room = _get_room_or_404(db, room_public_id)
    if not _can_manage_room_db(db, room, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the channel host/admin can manage room members")
    target = _get_user_or_404(db, target_public_user_id)
    participant = _upsert_saved_participant(db, room, target, is_member=is_member)
    participant.is_member = is_member
    if not is_member and not participant.is_room_admin and not participant.is_active:
        participant.left_at = datetime.utcnow()
    db.commit()
    db.refresh(participant)
    return participant_to_response(db, participant, room)


def set_room_admin(db: Session, room_public_id: str, current_user: User, target_public_user_id: int, is_admin: bool) -> RoomParticipantUserResponse:
    room = _get_room_or_404(db, room_public_id)
    if not _can_manage_room_db(db, room, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the channel host/admin can manage room admins")
    target = _get_user_or_404(db, target_public_user_id)
    participant = _upsert_saved_participant(db, room, target, is_member=is_admin, is_room_admin=is_admin)
    participant.is_room_admin = is_admin
    if is_admin:
        participant.is_member = True
    db.commit()
    db.refresh(participant)
    return participant_to_response(db, participant, room)
