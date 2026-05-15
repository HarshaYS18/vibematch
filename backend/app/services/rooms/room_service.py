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


def _set_room_lock_password(room: Room, lock_password: str | None, actor_user_id: int | None) -> None:
    clean_password = _clean_lock_password(lock_password)
    if clean_password is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Enter a room lock before locking the room.")
    room.lock_password_hash = hash_password(clean_password)
    room.lock_updated_at = datetime.utcnow()
    room.lock_updated_by_user_id = actor_user_id


def _clear_room_lock_password(room: Room) -> None:
    room.lock_password_hash = None
    room.lock_updated_at = None
    room.lock_updated_by_user_id = None


def _lock_password_matches(room: Room, lock_password: str | None) -> bool:
    clean_password = _clean_lock_password(lock_password)
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


def _room_access_denied_message(room: Room, *, lock_password: str | None = None) -> str:
    if room.is_secret:
        return "This Secret Vibe room is invite-only."
    if room.is_members_only:
        return "This room is members-only. Ask the channel host/admin for approval."
    if room.is_locked:
        if _clean_lock_password(lock_password) is None:
            return "This room is locked. Enter the room lock or use an invite from the channel owner/admin."
        return "Incorrect room lock. Try again or ask the channel owner/admin for an invite."
    return "Room not found or not accessible"


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


def _refresh_room_online_count(db: Session, room: Room) -> int:
    cutoff = datetime.utcnow() - _ACTIVE_PARTICIPANT_WINDOW
    now = datetime.utcnow()
    db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True), RoomParticipant.last_seen_at < cutoff).update({RoomParticipant.is_active: False, RoomParticipant.left_at: now}, synchronize_session=False)
    count = db.query(func.count(RoomParticipant.id)).filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True), RoomParticipant.last_seen_at >= cutoff).scalar() or 0
    room.online_count = count
    room.trending_score = max(room.trending_score, count)
    db.flush()
    return count


def cleanup_stale_room_participants(db: Session) -> int:
    cutoff = datetime.utcnow() - _ACTIVE_PARTICIPANT_WINDOW
    now = datetime.utcnow()
    updated = db.query(RoomParticipant).filter(RoomParticipant.is_active.is_(True), RoomParticipant.last_seen_at < cutoff).update({RoomParticipant.is_active: False, RoomParticipant.left_at: now}, synchronize_session=False)
    rooms = db.query(Room).filter(Room.is_active.is_(True)).all()
    for room in rooms:
        _refresh_room_online_count(db, room)
    db.commit()
    return int(updated or 0)


def room_to_trending_response(room: Room, followed_friends_inside: list[str] | None = None) -> RoomTrendingResponse:
    return RoomTrendingResponse(id=room.room_public_id, name=room.name, subtitle=room.subtitle, avatar_url=room.avatar_url, cover_photo_url=room.cover_photo_url or room.avatar_url, language=room.language, mode=room.mode, type=room.room_type, online_count=room.online_count, trending_score=room.trending_score, followed_friends_inside=followed_friends_inside or [])


def room_to_detail_response(room: Room) -> RoomDetailResponse:
    return RoomDetailResponse(id=room.room_public_id, name=room.name, subtitle=room.subtitle, avatar_url=room.avatar_url, cover_photo_url=room.cover_photo_url or room.avatar_url, language=room.language, mode=room.mode, type=room.room_type, online_count=room.online_count, trending_score=room.trending_score, followed_friends_inside=[], owner_user_id=room.owner_user_id, is_active=room.is_active, is_secret=room.is_secret, is_locked=room.is_locked, is_members_only=room.is_members_only, has_lock_password=bool((room.lock_password_hash or '').strip()))


def participant_to_response(db: Session, participant: RoomParticipant, room: Room) -> RoomParticipantUserResponse:
    user = participant.user
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
    wallet = economy_level_service.get_or_create_wallet(db, user.id)
    levels = economy_level_service.wallet_level_payload(db, wallet)
    economy_level_service.sync_vip_status(db, user.id, levels)
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
        vip=profile_service.vip_summary(db, user),
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
        existing_room = db.query(Room).filter(Room.owner_user_id == current_user.id).order_by(Room.created_at.asc()).first()
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
    room = db.query(Room).filter(Room.owner_user_id == current_user.id, Room.is_active.is_(True)).order_by(Room.created_at.asc()).first()
    if room is None:
        return None
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
    if not _can_enter_room(db, room, current_user, lock_password=lock_password):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=_room_access_denied_message(room, lock_password=lock_password))

    previous = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == current_user.id).first()
    was_active = previous.is_active if previous is not None else False
    participant = _upsert_active_participant(db, room, current_user)
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(room)
    db.refresh(participant)
    participants = roster_participants(db, room)
    db.commit()
    return RoomJoinResponse(room=room_to_detail_response(room), participants=[participant_to_response(db, item, room) for item in participants], joined_user=participant_to_response(db, participant, room), should_show_entered_message=not was_active)


def heartbeat_room(db: Session, room_public_id: str, current_user: User) -> RoomJoinResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if room is None:
        return None
    participant = _existing_participant(db, room, current_user)
    if participant is not None and participant.is_active:
        joined = join_room(db, room_public_id, current_user, lock_password=None)
        if joined is not None:
            joined.should_show_entered_message = False
        return joined
    joined = join_room(db, room_public_id, current_user, lock_password=None)
    if joined is not None:
        joined.should_show_entered_message = False
    return joined


def leave_room(db: Session, room_public_id: str, current_user: User) -> RoomLeaveResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        return None
    participant = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == current_user.id).first()
    if participant:
        participant.is_active = False
        participant.left_at = datetime.utcnow()
        participant.last_seen_at = datetime.utcnow()
    online_count = _refresh_room_online_count(db, room)
    db.commit()
    return RoomLeaveResponse(room_id=room.room_public_id, online_count=online_count, left=True)


def list_room_participants(db: Session, room_public_id: str, current_user: User) -> RoomParticipantsResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        return None
    if not _can_enter_room(db, room, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=_room_access_denied_message(room))
    participants = roster_participants(db, room)
    db.commit()
    db.refresh(room)
    return RoomParticipantsResponse(room_id=room.room_public_id, online_count=room.online_count, participants=[participant_to_response(db, item, room) for item in participants])


def set_room_member(db: Session, room_public_id: str, current_user: User, target_public_user_id: int, is_member: bool) -> RoomParticipantUserResponse:
    room = _get_room_or_404(db, room_public_id)
    if not _can_manage_room_db(db, room, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the channel host/admin or Owner can manage room members")
    target = _get_user_or_404(db, target_public_user_id)
    participant = _upsert_saved_participant(db, room, target, is_member=is_member, active=False)
    now = datetime.utcnow()
    participant.is_member = is_member or room.owner_user_id == target.id
    if not participant.is_member and participant.is_room_admin:
        participant.is_room_admin = False
    if participant.is_member:
        participant.member_added_at = participant.member_added_at or now
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(participant)
    return participant_to_response(db, participant, room)


def set_room_admin(db: Session, room_public_id: str, current_user: User, target_public_user_id: int, is_admin: bool) -> RoomParticipantUserResponse:
    room = _get_room_or_404(db, room_public_id)
    if not _can_manage_room_db(db, room, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the channel host/admin or Owner can manage room admins")
    target = _get_user_or_404(db, target_public_user_id)
    participant = _upsert_saved_participant(db, room, target, is_member=True if is_admin else False, is_room_admin=is_admin, active=False)
    now = datetime.utcnow()
    if room.owner_user_id == target.id:
        participant.is_member = True
        participant.is_room_admin = True
    else:
        participant.is_member = True if is_admin else participant.is_member
        participant.is_room_admin = is_admin
    if participant.is_member:
        participant.member_added_at = participant.member_added_at or now
    if participant.is_room_admin:
        participant.admin_added_at = participant.admin_added_at or now
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(participant)
    return participant_to_response(db, participant, room)


def list_trending_rooms(db: Session, language: str | None = None, category: str | None = None, limit: int = 30) -> list[RoomTrendingResponse]:
    stale_rooms = db.query(Room).filter(Room.is_active.is_(True)).all()
    for room in stale_rooms:
        _refresh_room_online_count(db, room)
    db.commit()

    query = db.query(Room).filter(Room.is_active.is_(True), Room.is_secret.is_(False), Room.is_locked.is_(False), Room.is_members_only.is_(False), Room.mode == "Open", Room.online_count > 0)

    if language and language != "All":
        query = query.filter(Room.language == language)
    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = query.order_by(Room.online_count.desc(), Room.trending_score.desc(), Room.created_at.desc()).limit(limit).all()
    return [room_to_trending_response(room) for room in rooms]


def list_following_rooms(db: Session, current_user: User, language: str | None = None, category: str | None = None, limit: int = 30) -> list[RoomTrendingResponse]:
    followed_rows = db.query(UserFollow.followed_user_id).filter(UserFollow.follower_user_id == current_user.id).all()
    followed_ids = [row[0] for row in followed_rows]
    if not followed_ids:
        return []

    for room in db.query(Room).filter(Room.is_active.is_(True), Room.owner_user_id.in_(followed_ids)).all():
        _refresh_room_online_count(db, room)
    db.commit()

    query = db.query(Room).filter(Room.is_active.is_(True), Room.is_secret.is_(False), Room.owner_user_id.in_(followed_ids))
    if language and language != "All":
        query = query.filter(Room.language == language)
    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = query.order_by(Room.online_count.desc(), Room.trending_score.desc(), Room.created_at.desc()).limit(limit).all()
    followed_users = {user.id: (user.display_name or user.username or str(user.public_user_id)) for user in db.query(User).filter(User.id.in_(followed_ids)).all()}
    return [room_to_trending_response(room, [followed_users.get(room.owner_user_id, "Friend")]) for room in rooms]
