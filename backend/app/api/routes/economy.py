import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool, GamePool, UserWallet
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.schemas.economy import EconomyDashboardResponse, EconomyPoolResponse, EconomyWalletResponse, GiftEconomyPreviewRequest, GiftEconomyPreviewResponse, GiftSendPublicRequest, GiftSendRequest, GiftSendResponse, RubyConversionRequest, RubyWithdrawRequestCreate
from app.services import economy_level_service, economy_service, gift_catalog_service, lucky_gift_house_service, lucky_gift_props_service, lucky_gift_stats_service
from app.services.rooms.room_contribution_service import room_contribution_rankings
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/economy", tags=["Economy"])


def _wallet_response(db: Session, wallet: UserWallet) -> EconomyWalletResponse:
    levels = economy_level_service.wallet_level_payload(db, wallet)
    return EconomyWalletResponse(
        user_id=wallet.user_id,
        coin_balance=wallet.coin_balance,
        ruby_balance=wallet.ruby_balance,
        withdrawable_rubies=max(wallet.ruby_balance - wallet.locked_ruby_balance, 0),
        pending_withdraw_rubies=wallet.pending_withdraw_rubies,
        lifetime_coins_spent=wallet.lifetime_coins_spent,
        lifetime_coins_received_as_gifts=wallet.lifetime_coins_received_as_gifts,
        lifetime_rubies_earned=wallet.lifetime_rubies_earned,
        lifetime_recharge_coin_exp=levels["lifetime_recharge_coin_exp"],
        monthly_recharge_coin_exp=levels["monthly_recharge_coin_exp"],
        monthly_gift_coins_sent=levels["monthly_gift_coins_sent"],
        monthly_gift_coins_received=levels["monthly_gift_coins_received"],
        lifetime_send_exp=levels["lifetime_send_exp"],
        lifetime_receive_exp=levels["lifetime_receive_exp"],
        vip=levels["vip"],
        svip=levels["svip"],
        sent=levels["sent"],
        received=levels["received"],
    )


def _pool_response(pool: CoinSupplyPool | GamePool | None) -> EconomyPoolResponse | None:
    if pool is None:
        return None
    return EconomyPoolResponse(
        id=pool.id,
        owner_user_id=getattr(pool, "owner_user_id", None),
        pool_type=pool.pool_type,
        balance=pool.balance,
        reserved_balance=pool.reserved_balance,
        status=pool.status,
    )


def _metadata_json(payload: dict) -> str:
    return json.dumps(jsonable_encoder(payload), separators=(",", ":"))


def _public_wallet_summary(db: Session, user: User) -> dict:
    wallet = economy_level_service.get_or_create_wallet(db, user.id)
    levels = economy_level_service.wallet_level_payload(db, wallet)
    economy_level_service.sync_vip_status(db, user.id, levels)
    return {
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
        "rule": "Mini profile Sent/Received are current-month gift coin totals. Sent Lv/Receive Lv use lifetime gift EXP.",
    }


def _private_wallet_payload(db: Session, user: User) -> dict:
    wallet = economy_level_service.get_or_create_wallet(db, user.id)
    payload = _wallet_response(db, wallet)
    if hasattr(payload, "model_dump"):
        return payload.model_dump(mode="json")
    return payload.dict()


def _active_room_user_ids(db: Session, room_id: int, sender_user_id: int, receiver_user_id: int) -> list[int]:
    ids = [sender_user_id, receiver_user_id]
    rows = db.query(RoomParticipant.user_id).filter(RoomParticipant.room_id == room_id, RoomParticipant.is_active.is_(True)).all()
    ids.extend(int(row[0]) for row in rows)
    return list(dict.fromkeys(ids))


def _room_from_public_id(db: Session, room_public_id: str | None) -> Room | None:
    clean = (room_public_id or "").strip()
    if not clean:
        return None
    room = db.query(Room).filter(Room.room_public_id == clean, Room.is_active.is_(True)).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def _receiver_from_public_id(db: Session, receiver_public_user_id: int) -> User:
    receiver = db.query(User).filter(User.public_user_id == receiver_public_user_id, User.is_active.is_(True), User.is_banned.is_(False)).first()
    if receiver is None:
        raise HTTPException(status_code=404, detail="Receiver not found")
    return receiver


async def _broadcast_user_level_updates(db: Session, sender_user_id: int, receiver_user_id: int) -> None:
    sender = db.query(User).filter(User.id == sender_user_id).first()
    receiver = db.query(User).filter(User.id == receiver_user_id).first()
    if sender is not None:
        await inbox_ws_manager.send_to_user(sender_user_id, {"event": "all_levels_updated", "payload": {"economy": _public_wallet_summary(db, sender), "wallet": _private_wallet_payload(db, sender)}})
    if receiver is not None:
        await inbox_ws_manager.send_to_user(receiver_user_id, {"event": "all_levels_updated", "payload": {"economy": _public_wallet_summary(db, receiver), "wallet": _private_wallet_payload(db, receiver)}})


async def _broadcast_room_level_and_rankings(db: Session, room_id: int | None, sender_user_id: int, receiver_user_id: int, exp_updates: dict) -> None:
    if room_id is None:
        return
    room = db.query(Room).filter(Room.id == room_id).first()
    if room is None:
        return
    user_ids = _active_room_user_ids(db, room_id, sender_user_id, receiver_user_id)
    room_exp = exp_updates.get("room") if isinstance(exp_updates, dict) else None
    rankings = room_contribution_rankings(db=db, room_public_id=room.room_public_id, category="sent", period="daily", limit=100)
    await inbox_ws_manager.broadcast_to_users(
        user_ids,
        {
            "event": "room_level_and_contribution_updated",
            "room_public_id": room.room_public_id,
            "room_level": room_exp,
            "contribution_rankings": rankings,
        },
    )


async def _broadcast_room_gift_event(
    db: Session,
    *,
    room: Room | None,
    sender: User,
    receiver: User,
    gift_id: str,
    coin_value: int,
    quantity: int,
    result: dict,
    is_lucky: bool = False,
) -> None:
    if room is None:
        return
    catalog_gift = gift_catalog_service.find_gift(gift_id) or {}
    gift_name = str(catalog_gift.get("name") or gift_id.replace("_", " ").title())
    total_coin_value = int(result.get("total_coin_value") or (int(coin_value) * int(quantity)))
    multiplier = int(result.get("lucky_multiplier") or 0)
    reward = int(result.get("lucky_reward_coin_amount") or 0)
    event_id = f"gift_{result.get('gift_transaction_id') or datetime.utcnow().timestamp()}_{receiver.id}"
    message = f"sent to {receiver.display_name or receiver.username or receiver.public_user_id} {gift_name} x{quantity}"
    if is_lucky and multiplier > 0:
        message = f"sent to {receiver.display_name or receiver.username or receiver.public_user_id} {gift_name} x{quantity} · {multiplier}x"
    await room_realtime_connections.broadcast_room(
        room.room_public_id,
        {
            "type": "room/system_event",
            "payload": {
                "id": event_id,
                "event_type": "room_gift_sent",
                "type": "room_gift_sent",
                "room_id": room.room_public_id,
                "actor_user_id": str(sender.id),
                "actor_public_user_id": sender.public_user_id,
                "actor_name": sender.display_name or sender.username or f"User {sender.public_user_id}",
                "actor_avatar_url": sender.avatar_url,
                "actor_vip_level": _public_wallet_summary(db, sender).get("vip_level", 0),
                "actor_sending_level": _public_wallet_summary(db, sender).get("sent_level", 0),
                "actor_receiving_level": _public_wallet_summary(db, sender).get("receive_level", 0),
                "target_user_id": str(receiver.id),
                "target_public_user_id": receiver.public_user_id,
                "target_name": receiver.display_name or receiver.username or f"User {receiver.public_user_id}",
                "message": message,
                "gift_id": gift_id,
                "gift_name": gift_name,
                "gift_category": catalog_gift.get("category") or ("lucky" if is_lucky else "classic"),
                "gift_type": catalog_gift.get("gift_type") or ("lucky" if is_lucky else "normal"),
                "quantity": quantity,
                "coin_value": coin_value,
                "total_coin_value": total_coin_value,
                "asset_url": catalog_gift.get("asset_url"),
                "video_url": catalog_gift.get("video_url"),
                "asset_path": catalog_gift.get("asset_path"),
                "video_asset_path": catalog_gift.get("video_asset_path"),
                "animation_type": catalog_gift.get("animation_type") or "image",
                "gift_version": catalog_gift.get("version") or 1,
                "catalog_version": catalog_gift.get("catalog_version") or gift_catalog_service.GIFT_CATALOG_VERSION,
                "show_gift_slide": bool(catalog_gift.get("show_gift_slide", True)),
                "show_premium_broadcast": bool(catalog_gift.get("show_premium_broadcast", False)),
                "show_gift_flight": bool(catalog_gift.get("show_gift_flight", True)),
                "ribbon_tier": "premium" if catalog_gift.get("show_premium_broadcast") else "normal",
                "broadcast_scope": "room",
                "is_lucky": is_lucky,
                "lucky_multiplier": multiplier,
                "lucky_reward_coin_amount": reward,
                "created_at": datetime.utcnow().isoformat(),
            },
        },
    )


async def _broadcast_after_gift(db: Session, *, room_id: int | None, sender_user_id: int, receiver_user_id: int, exp_updates: dict) -> None:
    await _broadcast_user_level_updates(db, sender_user_id, receiver_user_id)
    await _broadcast_room_level_and_rankings(db, room_id, sender_user_id, receiver_user_id, exp_updates)


@router.get("/me", response_model=EconomyDashboardResponse)
def get_my_economy_dashboard(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    data = economy_service.dashboard_for_user(db, current_user)
    return EconomyDashboardResponse(
        wallet=_wallet_response(db, data["wallet"]),
        seller_pool=_pool_response(data["seller_pool"]),
        merchant_pool=_pool_response(data["merchant_pool"]),
        gaming_pool=_pool_response(data["gaming_pool"]),
    )


@router.get("/users/public/{public_user_id}/summary")
def get_public_user_economy_summary(public_user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return _public_wallet_summary(db, user)


@router.get("/users/{user_id}/summary")
def get_user_economy_summary(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return _public_wallet_summary(db, user)


@router.post("/gifts/preview", response_model=GiftEconomyPreviewResponse)
def preview_gift_economy(payload: GiftEconomyPreviewRequest):
    return GiftEconomyPreviewResponse(
        **economy_service.preview_gift_economy(
            coin_value=payload.coin_value,
            quantity=payload.quantity,
            room_id=payload.room_id,
            relationship_id=payload.relationship_id,
            is_relationship_gift=payload.is_relationship_gift,
        )
    )


@router.post("/gifts/send", response_model=GiftSendResponse)
async def send_gift(
    payload: GiftSendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = economy_service.send_gift(
        db=db,
        sender=current_user,
        receiver_user_id=payload.receiver_user_id,
        gift_id=payload.gift_id,
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        room_id=payload.room_id,
        relationship_id=payload.relationship_id,
        is_relationship_gift=payload.is_relationship_gift,
    )
    exp_updates = result.get("experience_updates") if isinstance(result.get("experience_updates"), dict) else {}
    await inbox_ws_manager.send_to_user(current_user.id, {"event": "experience_updated", "scope": "send", "payload": exp_updates.get("sender")})
    await inbox_ws_manager.send_to_user(payload.receiver_user_id, {"event": "experience_updated", "scope": "receive", "payload": exp_updates.get("receiver"), "ruby": {"earned": result.get("receiver_ruby_amount"), "balance": result.get("receiver_ruby_balance"), "lifetime_rubies_earned": result.get("receiver_lifetime_rubies_earned")}})
    await _broadcast_after_gift(db, room_id=payload.room_id, sender_user_id=current_user.id, receiver_user_id=payload.receiver_user_id, exp_updates=exp_updates)
    return GiftSendResponse(**result)


@router.post("/gifts/send-public", response_model=GiftSendResponse)
async def send_gift_public(payload: GiftSendPublicRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    receiver = _receiver_from_public_id(db, payload.receiver_public_user_id)
    room = _room_from_public_id(db, payload.room_public_id)
    room_id = room.id if room is not None else None
    catalog_gift = gift_catalog_service.find_gift(payload.gift_id)
    coin_value = int(catalog_gift.get("coin_value") if catalog_gift is not None else payload.coin_value)
    result = economy_service.send_gift(
        db=db,
        sender=current_user,
        receiver_user_id=receiver.id,
        gift_id=payload.gift_id,
        coin_value=coin_value,
        quantity=payload.quantity,
        room_id=room_id,
        relationship_id=payload.relationship_id,
        is_relationship_gift=payload.is_relationship_gift,
    )
    exp_updates = result.get("experience_updates") if isinstance(result.get("experience_updates"), dict) else {}
    await _broadcast_after_gift(db, room_id=room_id, sender_user_id=current_user.id, receiver_user_id=receiver.id, exp_updates=exp_updates)
    await _broadcast_room_gift_event(
        db,
        room=room,
        sender=current_user,
        receiver=receiver,
        gift_id=payload.gift_id,
        coin_value=coin_value,
        quantity=payload.quantity,
        result=result,
        is_lucky=False,
    )
    return GiftSendResponse(**result)


@router.post("/gifts/send-lucky-public", response_model=GiftSendResponse)
async def send_lucky_gift_public(payload: GiftSendPublicRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    receiver = _receiver_from_public_id(db, payload.receiver_public_user_id)
    room = _room_from_public_id(db, payload.room_public_id)
    room_id = room.id if room is not None else None
    catalog_gift = gift_catalog_service.find_gift(payload.gift_id)
    coin_value = int(catalog_gift.get("coin_value") if catalog_gift is not None else payload.coin_value)
    try:
        total_coin_preview = int(coin_value) * int(payload.quantity)
        risk_result = lucky_gift_props_service.evaluate_whale_risk(db, user_id=current_user.id, spend_amount=total_coin_preview)
        if risk_result.get("action") != "ALLOW":
            raise HTTPException(status_code=429, detail={"message": "Lucky gift blocked by whale detection", "risk": risk_result})
        result = economy_service.send_gift(
            db=db,
            sender=current_user,
            receiver_user_id=receiver.id,
            gift_id=payload.gift_id,
            coin_value=coin_value,
            quantity=payload.quantity,
            room_id=room_id,
            relationship_id=payload.relationship_id,
            is_relationship_gift=payload.is_relationship_gift,
            commit=False,
        )
        total_coin_value = int(result["total_coin_value"])
        lucky_gift_house_service.record_spend_income(db, amount=total_coin_value, actor=current_user, source_id=f"lucky_gift:{result['gift_transaction_id']}", user_id=current_user.id, metadata={"gift_id": payload.gift_id, "receiver_user_id": receiver.id})
        lucky_result = lucky_gift_props_service.roll_lucky_gift(db, gift_id=payload.gift_id, gift_name=payload.gift_id.replace("_", " ").title(), base_coin_value=coin_value, quantity=payload.quantity, house_risk_score=int(risk_result.get("score") or 0))
        reward = int(lucky_result.get("reward_coin_amount") or 0)
        multiplier = int(lucky_result.get("multiplier") or 0)
        house_result = lucky_gift_house_service.validate_payout_exposure(db, payout_amount=reward)
        lucky_gift_house_service.record_payout(db, amount=reward, actor=current_user, source_id=f"lucky_gift:{result['gift_transaction_id']}", user_id=current_user.id, metadata={"gift_id": payload.gift_id, "multiplier": multiplier})
        sender_wallet = economy_service.credit_lucky_gift_reward(db, current_user.id, reward, f"lucky_gift:{result['gift_transaction_id']}", current_user.id, commit=False)
        lucky_tx, _ = lucky_gift_stats_service.record_lucky_gift_result(
            db,
            sender_user_id=current_user.id,
            receiver_user_id=receiver.id,
            room_id=room_id,
            gift_id=payload.gift_id,
            gift_name=payload.gift_id.replace("_", " ").title(),
            coin_value=coin_value,
            quantity=payload.quantity,
            spent_coins=total_coin_value,
            multiplier=multiplier,
            reward_coins=reward,
            net_win_coins=reward - total_coin_value,
            metadata_json=_metadata_json({"gift_transaction_id": result["gift_transaction_id"], "source": "send_lucky_public", "lucky_result": lucky_result, "risk": risk_result, "house": house_result}),
        )
        db.commit()
        db.refresh(sender_wallet)
        db.refresh(lucky_tx)
    except Exception:
        db.rollback()
        raise
    result["lucky_multiplier"] = multiplier
    result["lucky_reward_coin_amount"] = reward
    result["lucky_result"] = lucky_result
    result["lucky_difficulty"] = lucky_result.get("difficulty")
    result["risk_level"] = risk_result.get("level")
    result["risk_score"] = risk_result.get("score")
    result["risk_action"] = risk_result.get("action")
    result["lucky_gift_transaction_id"] = lucky_tx.id
    result["spent_coins"] = total_coin_value
    result["reward_coins"] = reward
    result["net_win_coins"] = reward - total_coin_value
    result["sender_coin_balance"] = sender_wallet.coin_balance
    result["winner_coin_balance"] = sender_wallet.coin_balance
    result["wallet_coin_balance"] = sender_wallet.coin_balance
    result["rule"] = f"Lucky gift committed for {total_coin_value} coins. Reward returned: {reward} coins. EXP and room rankings updated instantly."
    exp_updates = result.get("experience_updates") if isinstance(result.get("experience_updates"), dict) else {}
    await _broadcast_after_gift(db, room_id=room_id, sender_user_id=current_user.id, receiver_user_id=receiver.id, exp_updates=exp_updates)
    await _broadcast_room_gift_event(
        db,
        room=room,
        sender=current_user,
        receiver=receiver,
        gift_id=payload.gift_id,
        coin_value=coin_value,
        quantity=payload.quantity,
        result=result,
        is_lucky=True,
    )
    return GiftSendResponse(**result)


@router.post("/rubies/convert-to-coins", response_model=EconomyWalletResponse)
def convert_rubies_to_coins(payload: RubyConversionRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    wallet = economy_service.convert_rubies_to_coins(db, current_user, payload.ruby_amount)
    return _wallet_response(db, wallet)


@router.post("/rubies/withdraw")
def request_ruby_withdrawal(payload: RubyWithdrawRequestCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    request = economy_service.create_withdraw_request(
        db=db,
        user=current_user,
        ruby_amount=payload.ruby_amount,
        payout_method=payload.payout_method,
        payout_account_snapshot=payload.payout_account_snapshot,
    )
    return {"id": request.id, "ruby_amount": request.ruby_amount, "status": request.status}
