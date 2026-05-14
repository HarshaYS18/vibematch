from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.services import experience_service

router = APIRouter(prefix="/experience", tags=["Experience"])


@router.get("/me")
def get_my_experience(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Return current user's Send Lv and Receive Lv EXP details.

    This is intentionally not a ranking endpoint. The frontend Send Lv / Receive Lv
    pages should use this payload to show total EXP, current level progress,
    next-level requirement, and task guidance only.
    """
    return experience_service.details_for_user(db, current_user)


@router.get("/users/public/{public_user_id}")
def get_user_experience_by_public_id(public_user_id: int, db: Session = Depends(get_db)):
    payload = experience_service.details_for_public_user_id(db, public_user_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="User not found")
    return payload


@router.get("/rooms/{room_id}")
def get_room_experience(room_id: int, db: Session = Depends(get_db)):
    payload = experience_service.details_for_room(db, room_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return payload


@router.get("/tasks")
def get_experience_tasks():
    return {
        "send_tasks": [
            {"id": "send_gifts", "title": "Send gifts", "description": "Every coin spent on gifts adds Send EXP instantly.", "exp_rule": "1 coin gift value = 1 Send EXP"},
            {"id": "send_combo", "title": "Use gift combos", "description": "Combo quantity increases total gift value and Send EXP.", "exp_rule": "coin_value × quantity"},
        ],
        "receive_tasks": [
            {"id": "receive_gifts", "title": "Receive gifts", "description": "Every coin value received as gifts adds Receive EXP instantly.", "exp_rule": "1 received coin value = 1 Receive EXP"},
            {"id": "earn_rubies", "title": "Earn rubies from gifts", "description": "Gift receiver earns rubies from the ruby algorithm while Receive EXP grows.", "exp_rule": "rubies = 30% of received gift coin value"},
        ],
        "room_tasks": [
            {"id": "room_gifts", "title": "Grow room activity", "description": "Gifts sent inside a room add Room EXP instantly.", "exp_rule": "1 room gift coin value = 1 Room EXP"},
            {"id": "room_events", "title": "Host events", "description": "Future room events can add bonus Room EXP after backend task rules are enabled.", "exp_rule": "coming later"},
        ],
        "level_rule": "Level requirement uses a triangular curve: EXP needed for level N = 1000 × (N - 1) × N / 2, capped at Lv 200.",
    }
