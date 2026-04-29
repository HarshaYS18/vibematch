from sqlalchemy.orm import Session

from app.models.room import Room
from app.schemas.rooms.room import RoomTrendingResponse


MOCK_TRENDING_ROOMS: list[RoomTrendingResponse] = [
    RoomTrendingResponse(
        id="VM120451",
        name="Late Night Chill",
        subtitle="Soft talks, music and Telugu vibes",
        language="Telugu",
        mode="Open",
        type="Music",
        online_count=248,
        trending_score=9820,
        followed_friends_inside=["Riya", "Aman"],
    ),
    RoomTrendingResponse(
        id="VM881029",
        name="Hyderabad Friends Adda",
        subtitle="Casual chat room for Telugu friends",
        language="Telugu",
        mode="Locked",
        type="Chat",
        online_count=186,
        trending_score=8740,
        followed_friends_inside=["Meera"],
    ),
    RoomTrendingResponse(
        id="VM551482",
        name="Bollywood Vibe Sync",
        subtitle="Hindi songs, live energy and gifts",
        language="Hindi",
        mode="Vibe Sync",
        type="Music",
        online_count=452,
        trending_score=12940,
        followed_friends_inside=["Riya", "Kiran", "Aman"],
    ),
    RoomTrendingResponse(
        id="VM660410",
        name="English Talk Lounge",
        subtitle="Practice English and meet new friends",
        language="English",
        mode="Open",
        type="Chat",
        online_count=129,
        trending_score=6540,
        followed_friends_inside=[],
    ),
]


def list_trending_rooms(
    db: Session,
    language: str | None = None,
    category: str | None = None,
    limit: int = 30,
) -> list[RoomTrendingResponse]:
    """
    Return public trending room cards for Home.

    Uses DB rows when available; falls back to mock rooms while the room creation
    and seed flow are still being built.
    """

    query = db.query(Room).filter(Room.is_active.is_(True), Room.is_secret.is_(False))

    if language and language != "All":
        query = query.filter(Room.language == language)

    if category and category not in {"All", "Trending", "Following"}:
        query = query.filter(Room.room_type == category)

    rooms = (
        query.order_by(Room.trending_score.desc(), Room.online_count.desc())
        .limit(limit)
        .all()
    )

    if rooms:
        return [
            RoomTrendingResponse(
                id=room.room_public_id,
                name=room.name,
                subtitle=room.subtitle,
                language=room.language,
                mode=room.mode,
                type=room.room_type,
                online_count=room.online_count,
                trending_score=room.trending_score,
                followed_friends_inside=[],
            )
            for room in rooms
        ]

    mock_rooms = MOCK_TRENDING_ROOMS

    if language and language != "All":
        mock_rooms = [room for room in mock_rooms if room.language == language]

    if category and category not in {"All", "Trending", "Following"}:
        mock_rooms = [room for room in mock_rooms if room.type == category]

    return sorted(
        mock_rooms,
        key=lambda room: room.trending_score,
        reverse=True,
    )[:limit]
