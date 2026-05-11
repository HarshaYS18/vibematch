import random
from datetime import datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.follow import UserFollow
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.schemas.rooms.room import RoomCreateRequest, RoomDetailResponse, RoomJoinResponse, RoomLeaveResponse, RoomParticipantUserResponse, RoomParticipantsResponse, RoomTrendingResponse
from app.services import profile_service
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import get_primary_role, get_user_roles

_ACTIVE_PARTICIPANT_WINDOW = timedelta(minutes=2)
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


def _apply_room_payload(room: Room, payload: RoomCreateRequest) -> Room:
    mode = payload.mode.strip() or "Open"
    room_type = payload.type.strip() or "Chat"
    room.name = payload.name.strip()
    room.subtitle = payload.subtitle.strip() if payload.subtitle else None
    if payload.avatar_url and payload.avatar_url.strip():
        room.avatar_url = payload.avatar_url.strip()
    room.language = payload.language.strip() or "English"
    room.mode = mode
    room.room_type = room_type
    room.is_secret = mode == "Secret Vibe"
    room.is_locked = mode == "Locked"
    room.is_members_only = mode == "Members Only"
    room.is_active = True
    room.updated_at = datetime.utcnow()
    return room


def generate_room_public_id(db: Session) -> str:
    for _ in range(20):
        room_public_id = f"VM{random.randint(100000, 999999)}"
        if not _room_public_id_exists(db, room_public_id):
            return room_public_id
    raise RuntimeError("Could not generate unique room ID")


def _refresh_room_online_count(db: Session, room: Room) -> int:
    cutoff = datetime.utcnow() - _ACTIVE_PARTICIPANT_WINDOW
    db.query(RoomParticipant).filter(
        RoomParticipant.room_id == room.id,
        RoomParticipant.is_active.is_(True),
        RoomParticipant.last_seen_at < cutoff,
    ).update({RoomParticipant.is_active: False, RoomParticipant.left_at: datetime.utcnow()}, synchronize_session=False)
    count = db.query(func.count(RoomParticipant.id)).filter(
        RoomParticipant.room_id == room.id,
        RoomParticipant.is_active.is_(True),
    ).scalar() or 0
    room.online_count = count
    room.trending_score = max(room.trending_score, count)
    db.flush()
    return count


def room_to_trending_response(room: Room, followed_friends_inside: list[str] | None = None) -> RoomTrendingResponse:
    return RoomTrendingResponse(
        id=room.room_public_id,
        name=room.name,
        subtitle=room.subtitle,
        avatar_url=room.avatar_url,
        language=room.language,
        mode=room.mode,
        type=room.room_type,
        online_count=room.online_count,
        trending_score=room.trending_score,
        followed_friends_inside=followed_friends_inside or [],
    )


def room_to_detail_response(room: Room) -> RoomDetailResponse:
    return RoomDetailResponse(
        id=room.room_public_id,
        name=room.name,
        subtitle=room.subtitle,
        avatar_url=room.avatar_url,
        language=room.language,
        mode=room.mode,
        type=room.room_type,
        online_count=room.online_count,
        trending_score=room.trending_score,
        followed_friends_inside=[],
        owner_user_id=room.owner_user_id,
        is_active=room.is_active,
        is_secret=room.is_secret,
        is_locked=room.is_locked,
        is_members_only=room.is_members_only,
    )


def participant_to_response(db: Session, participant: RoomParticipant, room: Room) -> RoomParticipantUserResponse:
    user = participant.user
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
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
        is_owner=room.owner_user_id == user.id,
        joined_at=participant.joined_at,
        last_seen_at=participant.last_seen_at,
    )


def active_participants(db: Session, room: Room) -> list[RoomParticipant]:
    _refresh_room_online_count(db, room)
    return db.query(RoomParticipant).filter(
        RoomParticipant.room_id == room.id,
        RoomParticipant.is_active.is_(True),
    ).order_by(RoomParticipant.joined_at.asc()).all()


def create_room(db: Session, current_user: User, payload: RoomCreateRequest) -> RoomDetailResponse:
    if not _can_create_unlimited_rooms(current_user):
        existing_room = db.query(Room).filter(Room.owner_user_id == current_user.id).order_by(Room.created_at.asc()).first()
        if existing_room is not None:
            _apply_room_payload(existing_room, payload)
            _refresh_room_online_count(db, existing_room)
            db.commit()
            db.refresh(existing_room)
            return room_to_detail_response(existing_room)

    mode = payload.mode.strip() or "Open"
    room_type = payload.type.strip() or "Chat"
    room = Room(
        room_public_id=generate_room_public_id(db),
        owner_user_id=current_user.id,
        name=payload.name.strip(),
        subtitle=payload.subtitle.strip() if payload.subtitle else None,
        avatar_url=payload.avatar_url.strip() if payload.avatar_url else None,
        language=payload.language.strip() or "English",
        mode=mode,
        room_type=room_type,
        online_count=0,
        trending_score=1,
        is_secret=mode == "Secret Vibe",
        is_locked=mode == "Locked",
        is_members_only=mode == "Members Only",
        is_active=True,
    )
    db.add(room)
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


def join_room(db: Session, room_public_id: str, current_user: User) -> RoomJoinResponse | None:
    room = get_room_model_by_public_id(db, room_public_id)
    if not room:
        return None
    if room.is_secret and room.owner_user_id != current_user.id:
        return None

    now = datetime.utcnow()
    participant = db.query(RoomParticipant).filter(
        RoomParticipant.room_id == room.id,
        RoomParticipant.user_id == current_user.id,
    ).first()
    if participant is None:
        participant = RoomParticipant(room_id=room.id, user_id=current_user.id, is_active=True, joined_at=now, last_seen_at=now)
        db.add(participant)
    else:
        participant.is_active = True
        participant.last_seen_at = now
        participant.left_at = None
    current_user.last_seen_at = now
    _refresh_room_online_count(db, room)
    db.commit()
    db.refresh(room)
    participants = active_participants(db, room)
    db.commit()
    return RoomJoinResponse(room=room_to_detail_response(room), participants=[participant_to_response(db, item, room) for item in participants])


def heartbeat_room(db: Session, room_public_id: str, current_user: User) -> RoomJoinResponse | None:
    return join_room(db, room_public_id, current_user)


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
    if room.is_secret and room.owner_user_id != current_user.id:
        return None
    participants = active_participants(db, room)
    db.commit()
    db.refresh(room)
    return RoomParticipantsResponse(room_id=room.room_public_id, online_count=room.online_count, participants=[participant_to_response(db, item, room) for item in participants])


def list_trending_rooms(db: Session, language: str | None = None, category: str | None = None, limit: int = 30) -> list[RoomTrendingResponse]:
    """Return Home trending rooms. Trending intentionally shows active Open rooms with audience only."""

    stale_rooms = db.query(Room).filter(Room.is_active.is_(True)).all()
    for room in stale_rooms:
        _refresh_room_online_count(db, room)
    db.commit()

    query = db.query(Room).filter(
        Room.is_active.is_(True),
        Room.is_secret.is_(False),
        Room.is_locked.is_(False),
        Room.is_members_only.is_(False),
        Room.mode == "Open",
        Room.online_count > 0,
    )

    if language and language != "All":
        query = query.filter(Room.language == language)

    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = query.order_by(Room.online_count.desc(), Room.trending_score.desc(), Room.created_at.desc()).limit(limit).all()
    return [room_to_trending_response(room) for room in rooms]


def list_following_rooms(db: Session, current_user: User, language: str | None = None, category: str | None = None, limit: int = 30) -> list[RoomTrendingResponse]:
    """Return rooms owned by followed users. Secret Vibe rooms are never exposed here."""

    followed_rows = db.query(UserFollow.followed_user_id).filter(UserFollow.follower_user_id == current_user.id).all()
    followed_ids = [row[0] for row in followed_rows]
    if not followed_ids:
        return []

    for room in db.query(Room).filter(Room.is_active.is_(True), Room.owner_user_id.in_(followed_ids)).all():
        _refresh_room_online_count(db, room)
    db.commit()

    query = db.query(Room).filter(
        Room.is_active.is_(True),
        Room.is_secret.is_(False),
        Room.owner_user_id.in_(followed_ids),
    )

    if language and language != "All":
        query = query.filter(Room.language == language)

    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = query.order_by(Room.online_count.desc(), Room.trending_score.desc(), Room.created_at.desc()).limit(limit).all()
    followed_users = {user.id: (user.display_name or user.username or str(user.public_user_id)) for user in db.query(User).filter(User.id.in_(followed_ids)).all()}
    return [room_to_trending_response(room, [followed_users.get(room.owner_user_id, "Friend")]) for room in rooms]
