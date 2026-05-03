import random

from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.user import User
from app.schemas.rooms.room import RoomCreateRequest, RoomCreateResponse, RoomTrendingResponse


def _generate_room_public_id(db: Session) -> str:
    for _ in range(30):
        candidate = f"VM{random.randint(100000, 999999)}"
        exists = db.query(Room).filter(Room.room_public_id == candidate).first()
        if exists is None:
            return candidate
    raise RuntimeError("Could not generate unique room ID")


def _room_to_trending_response(room: Room) -> RoomTrendingResponse:
    return RoomTrendingResponse(
        id=room.room_public_id,
        name=room.name,
        subtitle=room.subtitle,
        language=room.language,
        mode=room.mode,
        type=room.room_type,
        online_count=room.online_count,
        trending_score=room.trending_score,
        followed_friends_inside=[],
        cover_image_url=getattr(room, "cover_image_url", None),
    )


def _room_to_create_response(room: Room) -> RoomCreateResponse:
    return RoomCreateResponse(
        id=room.room_public_id,
        name=room.name,
        subtitle=room.subtitle,
        language=room.language,
        mode=room.mode,
        type=room.room_type,
        online_count=room.online_count,
        trending_score=room.trending_score,
        followed_friends_inside=[],
        cover_image_url=getattr(room, "cover_image_url", None),
        owner_user_id=room.owner_user_id or 0,
        is_active=room.is_active,
        is_secret=room.is_secret,
        is_locked=room.is_locked,
        is_members_only=room.is_members_only,
    )


def create_room(
    *,
    db: Session,
    owner: User,
    payload: RoomCreateRequest,
) -> RoomCreateResponse:
    mode = payload.mode.strip() or "Open"
    room_type = payload.type.strip() or "Chat"

    room = Room(
        room_public_id=_generate_room_public_id(db),
        owner_user_id=owner.id,
        name=payload.name.strip(),
        subtitle=None,
        language=payload.language.strip() or "English",
        mode=mode,
        room_type=room_type,
        online_count=0,
        trending_score=0,
        is_active=True,
        is_secret=mode.lower() in {"secret vibe", "private vibe", "secret"},
        is_locked=mode.lower() == "locked",
        is_members_only=mode.lower() == "members only",
    )

    if hasattr(room, "cover_image_url"):
        room.cover_image_url = payload.cover_image_url

    db.add(room)
    db.commit()
    db.refresh(room)

    return _room_to_create_response(room)


def list_trending_rooms(
    db: Session,
    language: str | None = None,
    category: str | None = None,
    limit: int = 30,
) -> list[RoomTrendingResponse]:
    """Return real public trending room cards for Home.

    No mock fallback is allowed here. If there are no DB rooms, Home must show
    an empty state until a room is created through the real create-room API.
    """

    query = db.query(Room).filter(Room.is_active.is_(True), Room.is_secret.is_(False))

    if language and language != "All":
        query = query.filter(Room.language == language)

    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = (
        query.order_by(Room.trending_score.desc(), Room.online_count.desc(), Room.created_at.desc())
        .limit(limit)
        .all()
    )

    return [_room_to_trending_response(room) for room in rooms]
