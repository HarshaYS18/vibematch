from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.services import experience_service
from app.services.rooms.room_contribution_service import room_contribution_rankings

router = APIRouter(prefix="/rooms", tags=["Room Levels And Rankings"])


@router.get("/{room_public_id}/level")
def get_room_level(room_public_id: str, db: Session = Depends(get_db)):
    payload = experience_service.details_for_room_public_id(db, room_public_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return payload


@router.get("/{room_public_id}/level/history")
def get_room_level_history(room_public_id: str, db: Session = Depends(get_db)):
    payload = experience_service.details_for_room_public_id(db, room_public_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="Room not found")
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
