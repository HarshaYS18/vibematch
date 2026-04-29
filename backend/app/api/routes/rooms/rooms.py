from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.rooms.room import RoomTrendingResponse
from app.services.rooms.room_service import list_trending_rooms


router = APIRouter(prefix="/rooms", tags=["Rooms"])


@router.get("/trending", response_model=list[RoomTrendingResponse])
def get_trending_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return list_trending_rooms(
        db=db,
        language=language,
        category=category,
        limit=limit,
    )
