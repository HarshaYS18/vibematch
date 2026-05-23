from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.presence import UserRoomPresence
from app.models.room import Room
from app.services import experience_service
from app.services.rooms.room_contribution_service import room_contribution_rankings

router = APIRouter(prefix="/rooms", tags=["Room Levels And Rankings"])


def _safe_room_level_payload(db: Session, room_public_id: str) -> dict | None:
    clean_room_public_id = room_public_id.strip()
    if not clean_room_public_id:
        return None

    room = db.query(Room).filter(Room.room_public_id == clean_room_public_id).first()
    active_count = (
        db.query(UserRoomPresence.id)
        .filter(
            UserRoomPresence.room_public_id == clean_room_public_id,
            UserRoomPresence.is_active.is_(True),
            UserRoomPresence.is_secret.is_(False),
        )
        .count()
    )

    if room is None:
        # A room can exist only in the realtime/presence layer during early beta
        # before the persisted Room row is visible. Keep the client stable and
        # show level 1 instead of returning 404 while the room is live.
        return {
            "room_public_id": clean_room_public_id,
            "level": 1,
            "exp": 0,
            "current_exp": 0,
            "current_level_exp": 0,
            "next_level_exp": 1000,
            "progress": 0.0,
            "rank": None,
            "monthly_score": 0,
            "weekly_score": 0,
            "today_score": 0,
            "online_count": active_count,
            "trending_score": 0,
            "name": "Live Room",
        }

    trending_score = max(int(room.trending_score or 0), 0)
    online_count = max(int(room.online_count or 0), active_count)
    exp = max(trending_score * 10 + online_count * 25, 0)
    level = max(1, min((exp // 1000) + 1, 99))
    current_level_exp = (level - 1) * 1000
    next_level_exp = level * 1000
    progress = 0.0 if next_level_exp <= current_level_exp else min(
        max((exp - current_level_exp) / (next_level_exp - current_level_exp), 0.0),
        1.0,
    )

    return {
        "room_public_id": clean_room_public_id,
        "level": level,
        "exp": exp,
        "current_exp": exp,
        "current_level_exp": current_level_exp,
        "next_level_exp": next_level_exp,
        "progress": progress,
        "rank": None,
        "monthly_score": 0,
        "weekly_score": 0,
        "today_score": 0,
        "online_count": online_count,
        "trending_score": trending_score,
        "name": room.name or "Live Room",
    }


@router.get("/{room_public_id}/level")
def get_room_level(room_public_id: str, db: Session = Depends(get_db)):
    payload = experience_service.details_for_room_public_id(db, room_public_id)
    if payload is None:
        payload = _safe_room_level_payload(db, room_public_id)
    if payload is None:
        raise HTTPException(status_code=400, detail="Room ID is required")
    return payload


@router.get("/{room_public_id}/level/history")
def get_room_level_history(room_public_id: str, db: Session = Depends(get_db)):
    payload = experience_service.details_for_room_public_id(db, room_public_id)
    if payload is None:
        payload = _safe_room_level_payload(db, room_public_id)
    if payload is None:
        raise HTTPException(status_code=400, detail="Room ID is required")
    return {
        "room_public_id": room_public_id,
        "current": payload,
        "history": [],
        "note": "Room EXP history table will be populated by the economy event ledger in the next migration phase.",
    }


@router.get("/{room_public_id}/rankings/contribution")
def get_room_contribution_ranking(
    room_public_id: str,
    period: str = Query(default="daily"),
    category: str = Query(default="sent"),
    limit: int = Query(default=100, ge=1, le=100),
    db: Session = Depends(get_db),
):
    payload = room_contribution_rankings(db=db, room_public_id=room_public_id, category=category, period=period, limit=limit)
    if payload is None:
        raise HTTPException(status_code=404, detail="Room not found")
    payload["ranking_type"] = "room_contribution"
    return payload
