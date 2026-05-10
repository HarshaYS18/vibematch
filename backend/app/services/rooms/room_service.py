import random
from sqlalchemy.orm import Session

from app.models.follow import UserFollow
from app.models.room import Room
from app.models.user import User
from app.schemas.rooms.room import RoomCreateRequest, RoomDetailResponse, RoomTrendingResponse


def _room_public_id_exists(db: Session, room_public_id: str) -> bool:
    return db.query(Room.id).filter(Room.room_public_id == room_public_id).first() is not None


def generate_room_public_id(db: Session) -> str:
    for _ in range(20):
        room_public_id = f"VM{random.randint(100000, 999999)}"
        if not _room_public_id_exists(db, room_public_id):
            return room_public_id
    raise RuntimeError("Could not generate unique room ID")


def room_to_trending_response(room: Room, followed_friends_inside: list[str] | None = None) -> RoomTrendingResponse:
    return RoomTrendingResponse(
        id=room.room_public_id,
        name=room.name,
        subtitle=room.subtitle,
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


def create_room(db: Session, current_user: User, payload: RoomCreateRequest) -> RoomDetailResponse:
    mode = payload.mode.strip() or "Open"
    room_type = payload.type.strip() or "Chat"
    room = Room(
        room_public_id=generate_room_public_id(db),
        owner_user_id=current_user.id,
        name=payload.name.strip(),
        subtitle=payload.subtitle.strip() if payload.subtitle else None,
        language=payload.language.strip() or "English",
        mode=mode,
        room_type=room_type,
        online_count=1,
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


def get_room_by_public_id(db: Session, room_public_id: str) -> RoomDetailResponse | None:
    room = db.query(Room).filter(Room.room_public_id == room_public_id, Room.is_active.is_(True)).first()
    if not room:
        return None
    return room_to_detail_response(room)


def list_trending_rooms(
    db: Session,
    language: str | None = None,
    category: str | None = None,
    limit: int = 30,
) -> list[RoomTrendingResponse]:
    """Return Home trending rooms. Trending intentionally shows Open rooms only."""

    query = db.query(Room).filter(
        Room.is_active.is_(True),
        Room.is_secret.is_(False),
        Room.is_locked.is_(False),
        Room.is_members_only.is_(False),
        Room.mode == "Open",
    )

    if language and language != "All":
        query = query.filter(Room.language == language)

    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = (
        query.order_by(Room.trending_score.desc(), Room.online_count.desc(), Room.created_at.desc())
        .limit(limit)
        .all()
    )

    return [room_to_trending_response(room) for room in rooms]


def list_following_rooms(
    db: Session,
    current_user: User,
    language: str | None = None,
    category: str | None = None,
    limit: int = 30,
) -> list[RoomTrendingResponse]:
    """Return rooms owned by followed users. Secret Vibe rooms are never exposed here."""

    followed_rows = db.query(UserFollow.followed_user_id).filter(UserFollow.follower_user_id == current_user.id).all()
    followed_ids = [row[0] for row in followed_rows]
    if not followed_ids:
        return []

    query = db.query(Room).filter(
        Room.is_active.is_(True),
        Room.is_secret.is_(False),
        Room.owner_user_id.in_(followed_ids),
    )

    if language and language != "All":
        query = query.filter(Room.language == language)

    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = (
        query.order_by(Room.online_count.desc(), Room.trending_score.desc(), Room.created_at.desc())
        .limit(limit)
        .all()
    )

    followed_users = {user.id: (user.display_name or user.username or str(user.public_user_id)) for user in db.query(User).filter(User.id.in_(followed_ids)).all()}
    return [room_to_trending_response(room, [followed_users.get(room.owner_user_id, "Friend")]) for room in rooms]
