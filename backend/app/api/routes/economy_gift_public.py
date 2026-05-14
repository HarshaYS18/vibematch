from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.room import Room
from app.models.user import User
from app.services import economy_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/economy/gifts", tags=["Economy"])


class PublicGiftSendRequest(BaseModel):
    receiver_public_user_id: int = Field(..., gt=0)
    gift_id: str = Field(..., min_length=1, max_length=80)
    coin_value: int = Field(..., gt=0)
    quantity: int = Field(default=1, gt=0)
    room_public_id: str | None = Field(default=None, max_length=80)
    relationship_id: int | None = None
    is_relationship_gift: bool = False


@router.post("/send-public")
async def send_gift_by_public_ids(
    payload: PublicGiftSendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    receiver = db.query(User).filter(User.public_user_id == payload.receiver_public_user_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver not found")

    room_id: int | None = None
    if payload.room_public_id:
        room = db.query(Room).filter(Room.room_public_id == payload.room_public_id).first()
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        room_id = room.id

    result = economy_service.send_gift(
        db=db,
        sender=current_user,
        receiver_user_id=receiver.id,
        gift_id=payload.gift_id,
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        room_id=room_id,
        relationship_id=payload.relationship_id,
        is_relationship_gift=payload.is_relationship_gift,
    )

    exp_updates = result.get("experience_updates") if isinstance(result.get("experience_updates"), dict) else {}
    await inbox_ws_manager.send_to_user(
        current_user.id,
        {"event": "experience_updated", "scope": "send", "payload": exp_updates.get("sender")},
    )
    await inbox_ws_manager.send_to_user(
        receiver.id,
        {
            "event": "experience_updated",
            "scope": "receive",
            "payload": exp_updates.get("receiver"),
            "ruby": {
                "earned": result.get("receiver_ruby_amount"),
                "balance": result.get("receiver_ruby_balance"),
                "lifetime_rubies_earned": result.get("receiver_lifetime_rubies_earned"),
                "lifetime_gift_coin_value": result.get("receiver_lifetime_gift_coin_value"),
            },
        },
    )
    if exp_updates.get("room") is not None:
        await inbox_ws_manager.broadcast_to_users(
            [current_user.id, receiver.id],
            {"event": "room_experience_updated", "payload": exp_updates.get("room")},
        )

    return result
