from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.services import experience_service

router = APIRouter(prefix="/experience/rooms/public", tags=["Experience"])


@router.get("/{room_public_id}")
def get_room_experience_by_public_id(room_public_id: str, db: Session = Depends(get_db)):
    payload = experience_service.details_for_room_public_id(db, room_public_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return payload
