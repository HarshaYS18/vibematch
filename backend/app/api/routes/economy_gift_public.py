from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.room import Room
from app.models.user import User
from app.services import economy_level_service, economy_service, gift_catalog_service
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


class PublicLuckyGiftSendRequest(PublicGiftSendRequest):
    house_risk_score: int = Field(default=0, ge=0, le=100)


async def _broadcast_gift_experience_updates(
    *,
    db: Session,
    current_user_id: int,
    receiver_user_id: int,
    result: dict,
) -> None:
    exp_updates = result.get("experience_updates") if isinstance(result.get("experience_updates"), dict) else {}
    await inbox_ws_manager.send_to_user(
        current_user_id,
        {"event": "experience_updated", "scope": "send", "payload": exp_updates.get("sender")},
    )
    await inbox_ws_manager.send_to_user(
        receiver_user_id,
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
            [current_user_id, receiver_user_id],
            {"event": "room_experience_updated", "payload": exp_updates.get("room")},
        )
    await _broadcast_all_levels(db=db, user_ids=[current_user_id, receiver_user_id])


def _level_payload_for_user(db: Session, user: User) -> tuple[dict, dict]:
    wallet = economy_level_service.get_or_create_wallet(db, user.id)
    levels = economy_level_service.wallet_level_payload(db, wallet)
    economy_level_service.sync_vip_status(db, user.id, levels)
    public_summary = {
        "user_id": user.id,
        "public_user_id": user.public_user_id,
        "display_name": user.display_name or user.username,
        "avatar_url": user.avatar_url,
        "monthly_gift_coins_sent": levels["monthly_gift_coins_sent"],
        "monthly_gift_coins_received": levels["monthly_gift_coins_received"],
        "lifetime_send_exp": levels["lifetime_send_exp"],
        "lifetime_receive_exp": levels["lifetime_receive_exp"],
        "sent_level": levels["sent"].get("level", 0),
        "receive_level": levels["received"].get("level", 0),
        "vip_level": levels["vip"].get("level", 0),
        "svip_level": levels["svip"].get("level", 0),
        "sent": levels["sent"],
        "received": levels["received"],
        "vip": levels["vip"],
        "svip": levels["svip"],
    }
    private_wallet = {
        **public_summary,
        "coin_balance": wallet.coin_balance,
        "ruby_balance": wallet.ruby_balance,
        "withdrawable_rubies": max(wallet.ruby_balance - wallet.locked_ruby_balance, 0),
        "pending_withdraw_rubies": wallet.pending_withdraw_rubies,
        "lifetime_coins_spent": wallet.lifetime_coins_spent,
        "lifetime_coins_received_as_gifts": wallet.lifetime_coins_received_as_gifts,
        "lifetime_rubies_earned": wallet.lifetime_rubies_earned,
    }
    return public_summary, private_wallet


async def _broadcast_all_levels(*, db: Session, user_ids: list[int]) -> None:
    users = db.query(User).filter(User.id.in_(list(dict.fromkeys(user_ids)))).all()
    for user in users:
        economy, wallet = _level_payload_for_user(db, user)
        await inbox_ws_manager.send_to_user(user.id, {"event": "all_levels_updated", "payload": {"economy": economy, "wallet": wallet}})


def _resolve_receiver_and_room(db: Session, payload: PublicGiftSendRequest) -> tuple[User, int | None]:
    receiver = db.query(User).filter(User.public_user_id == payload.receiver_public_user_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver not found")

    room_id: int | None = None
    if payload.room_public_id:
        room = db.query(Room).filter(Room.room_public_id == payload.room_public_id).first()
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        room_id = room.id

    return receiver, room_id


@router.post("/send-public")
async def send_gift_by_public_ids(
    payload: PublicGiftSendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    receiver, room_id = _resolve_receiver_and_room(db, payload)

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

    await _broadcast_gift_experience_updates(
        db=db,
        current_user_id=current_user.id,
        receiver_user_id=receiver.id,
        result=result,
    )

    return result


@router.post("/send-lucky-public")
async def send_lucky_gift_by_public_ids(
    payload: PublicLuckyGiftSendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    gift = gift_catalog_service.find_gift(payload.gift_id)
    if gift is None:
        raise HTTPException(status_code=404, detail="Gift not found")
    if gift.get("gift_type") != "lucky":
        raise HTTPException(status_code=400, detail="Gift is not a lucky gift")
    if int(gift.get("coin_value") or 0) != payload.coin_value:
        raise HTTPException(status_code=400, detail="Gift coin value does not match catalog")

    receiver, room_id = _resolve_receiver_and_room(db, payload)

    lucky_result = gift_catalog_service.roll_lucky_multiplier(
        gift_id=payload.gift_id,
        total_coin_value=payload.coin_value * payload.quantity,
        house_risk_score=payload.house_risk_score,
    )

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

    reward_wallet = economy_service.credit_lucky_gift_reward(
        db=db,
        user_id=current_user.id,
        reward_coin_amount=int(lucky_result["reward_coin_amount"]),
        source_id=f"lucky_gift:{result['gift_transaction_id']}",
        created_by_user_id=current_user.id,
    )

    result["lucky_result"] = lucky_result
    result["sender_coin_balance"] = reward_wallet.coin_balance
    result["lucky_reward_coin_amount"] = lucky_result["reward_coin_amount"]
    result["lucky_multiplier"] = lucky_result["multiplier"]

    await _broadcast_gift_experience_updates(
        db=db,
        current_user_id=current_user.id,
        receiver_user_id=receiver.id,
        result=result,
    )
    await inbox_ws_manager.send_to_user(
        current_user.id,
        {
            "event": "lucky_gift_result",
            "payload": {
                "gift_transaction_id": result["gift_transaction_id"],
                "gift_id": payload.gift_id,
                "receiver_user_id": receiver.id,
                "room_public_id": payload.room_public_id,
                "lucky_result": lucky_result,
                "sender_coin_balance": reward_wallet.coin_balance,
            },
        },
    )

    return result
