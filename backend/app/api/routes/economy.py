import json
from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool, GamePool, UserWallet
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.schemas.economy import (
    EconomyDashboardResponse,
    EconomyPoolResponse,
    EconomyWalletResponse,
    GiftEconomyPreviewRequest,
    GiftEconomyPreviewResponse,
    GiftSendPublicRequest,
    GiftSendResponse,
)
from app.services import (
    economy_level_service,
    economy_service,
    economy_service_client,
    experience_service,
    gift_catalog_service,
    lucky_gift_house_service,
    lucky_gift_props_service,
    lucky_gift_stats_service,
)
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
    return payload.model_dump(mode="json") if hasattr(payload, "model_dump") else payload.dict()


def _active_room_user_ids(
    db: Session,
    room_id: int,
    sender_user_id: int,
    receiver_user_id: int,
) -> list[int]:
    ids = [sender_user_id, receiver_user_id]
    rows = (
        db.query(RoomParticipant.user_id)
        .filter(
            RoomParticipant.room_id == room_id,
            RoomParticipant.is_active.is_(True),
        )
        .all()
    )
    ids.extend(int(row[0]) for row in rows)
    return list(dict.fromkeys(ids))


def _room_from_public_id(db: Session, room_public_id: str | None) -> Room | None:
    clean = (room_public_id or "").strip()
    if not clean:
        return None
    room = (
        db.query(Room)
        .filter(Room.room_public_id == clean, Room.is_active.is_(True))
        .first()
    )
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def _receiver_from_public_id(db: Session, receiver_public_user_id: int) -> User:
    receiver = (
        db.query(User)
        .filter(
            User.public_user_id == receiver_public_user_id,
            User.is_active.is_(True),
            User.is_banned.is_(False),
        )
        .first()
    )
    if receiver is None:
        raise HTTPException(status_code=404, detail="Receiver not found")
    return receiver


def _catalog_gift_or_error(
    db: Session,
    gift_id: str,
    quantity: int,
    *,
    require_lucky: bool = False,
) -> dict:
    gift = gift_catalog_service.find_gift(gift_id, db=db)
    if gift is None:
        raise HTTPException(status_code=404, detail="Gift not found")
    if require_lucky and str(gift.get("gift_type") or "").lower() != "lucky":
        raise HTTPException(status_code=400, detail="Gift is not a lucky gift")
    try:
        gift_catalog_service.validate_gift_combo(gift, quantity)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return gift


def _require_room_gift_presence(
    db: Session,
    room: Room | None,
    sender_user_id: int,
    receiver_user_id: int,
) -> None:
    if room is None:
        return
    rows = (
        db.query(RoomParticipant.user_id)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.user_id.in_([sender_user_id, receiver_user_id]),
            RoomParticipant.is_active.is_(True),
        )
        .all()
    )
    active_ids = {int(row[0]) for row in rows}
    if sender_user_id not in active_ids:
        raise HTTPException(
            status_code=409,
            detail="Sender is not actively present in this room",
        )
    if receiver_user_id not in active_ids:
        raise HTTPException(
            status_code=409,
            detail="Receiver is not actively present in this room",
        )


def _room_user_id(user: User) -> str:
    return f"user_{user.public_user_id}"


def _queue_user_level_updates(
    background_tasks: BackgroundTasks,
    db: Session,
    sender_user_id: int,
    receiver_user_id: int,
) -> None:
    sender = db.query(User).filter(User.id == sender_user_id).first()
    receiver = db.query(User).filter(User.id == receiver_user_id).first()
    if sender is not None:
        background_tasks.add_task(
            inbox_ws_manager.send_to_user,
            sender_user_id,
            {
                "event": "all_levels_updated",
                "payload": {
                    "economy": _public_wallet_summary(db, sender),
                    "wallet": _private_wallet_payload(db, sender),
                },
            },
        )
    if receiver is not None:
        background_tasks.add_task(
            inbox_ws_manager.send_to_user,
            receiver_user_id,
            {
                "event": "all_levels_updated",
                "payload": {
                    "economy": _public_wallet_summary(db, receiver),
                    "wallet": _private_wallet_payload(db, receiver),
                },
            },
        )


def _queue_room_level_and_rankings(
    background_tasks: BackgroundTasks,
    db: Session,
    room_id: int | None,
    sender_user_id: int,
    receiver_user_id: int,
    exp_updates: dict,
) -> None:
    if room_id is None:
        return
    room = db.query(Room).filter(Room.id == room_id).first()
    if room is None:
        return
    user_ids = _active_room_user_ids(db, room_id, sender_user_id, receiver_user_id)
    room_exp = exp_updates.get("room") if isinstance(exp_updates, dict) else None
    rankings = room_contribution_rankings(
        db=db,
        room_public_id=room.room_public_id,
        category="sent",
        period="daily",
        limit=100,
    )
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        user_ids,
        {
            "event": "room_level_and_contribution_updated",
            "room_public_id": room.room_public_id,
            "room_level": room_exp,
            "contribution_rankings": rankings,
        },
    )


def _queue_room_gift_event(
    background_tasks: BackgroundTasks,
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

    catalog_gift = gift_catalog_service.find_gift(gift_id, db=db) or {}
    sender_summary = _public_wallet_summary(db, sender)
    gift_name = str(
        catalog_gift.get("name") or gift_id.replace("_", " ").title()
    )
    total_coin_value = int(
        result.get("total_coin_value") or (int(coin_value) * int(quantity))
    )
    multiplier = int(result.get("lucky_multiplier") or 0)
    reward = int(result.get("lucky_reward_coin_amount") or 0)
    lucky_result = (
        result.get("lucky_result")
        if isinstance(result.get("lucky_result"), dict)
        else {}
    )
    event_id = (
        f"gift_{result.get('gift_transaction_id') or datetime.utcnow().timestamp()}_"
        f"{receiver.public_user_id}"
    )
    receiver_name = receiver.display_name or receiver.username or str(receiver.public_user_id)
    message = f"sent to {receiver_name} {gift_name} x{quantity}"
    if is_lucky:
        suffix = "try again" if multiplier <= 0 else f"{multiplier}x"
        message = f"sent to {receiver_name} {gift_name} x{quantity} · {suffix}"

    background_tasks.add_task(
        room_realtime_connections.broadcast_room,
        room.room_public_id,
        {
            "type": "room/system_event",
            "payload": {
                "id": event_id,
                "event_type": "room_gift_sent",
                "type": "room_gift_sent",
                "room_id": room.room_public_id,
                "actor_user_id": _room_user_id(sender),
                "actor_public_user_id": sender.public_user_id,
                "actor_name": sender.display_name
                or sender.username
                or f"User {sender.public_user_id}",
                "actor_avatar_url": sender.avatar_url,
                "actor_vip_level": sender_summary.get("vip_level", 0),
                "actor_sending_level": sender_summary.get("sent_level", 0),
                "actor_receiving_level": sender_summary.get("receive_level", 0),
                "target_user_id": _room_user_id(receiver),
                "target_public_user_id": receiver.public_user_id,
                "target_name": receiver_name,
                "message": message,
                "gift_id": gift_id,
                "gift_name": gift_name,
                "gift_category": catalog_gift.get("category")
                or ("lucky" if is_lucky else "classic"),
                "gift_type": catalog_gift.get("gift_type")
                or ("lucky" if is_lucky else "normal"),
                "icon_key": catalog_gift.get("icon_key"),
                "chat_symbol": catalog_gift.get("chat_symbol"),
                "quantity": quantity,
                "coin_value": coin_value,
                "total_coin_value": total_coin_value,
                "asset_url": catalog_gift.get("asset_url"),
                "video_url": catalog_gift.get("video_url"),
                "asset_path": catalog_gift.get("asset_path"),
                "video_asset_path": catalog_gift.get("video_asset_path"),
                "animation_type": catalog_gift.get("animation_type") or "image",
                "gift_version": catalog_gift.get("version") or 1,
                "catalog_version": catalog_gift.get("catalog_version")
                or gift_catalog_service.GIFT_CATALOG_VERSION,
                "show_gift_slide": bool(catalog_gift.get("show_gift_slide", True)),
                "show_premium_broadcast": bool(
                    catalog_gift.get("show_premium_broadcast", False)
                )
                or bool(lucky_result.get("is_broadcast_win")),
                "show_gift_flight": bool(catalog_gift.get("show_gift_flight", True)),
                "ribbon_tier": "premium"
                if catalog_gift.get("show_premium_broadcast")
                or lucky_result.get("is_big_win")
                else "normal",
                "broadcast_scope": "room",
                "is_lucky": is_lucky,
                "lucky_multiplier": multiplier,
                "lucky_reward_coin_amount": reward,
                "lucky_tier": lucky_result.get("tier"),
                "lucky_display_tier": lucky_result.get("display_tier"),
                "lucky_near_miss": lucky_result.get("near_miss"),
                "created_at": datetime.utcnow().isoformat(),
            },
        },
    )


def _queue_after_gift(
    background_tasks: BackgroundTasks,
    db: Session,
    *,
    room_id: int | None,
    sender_user_id: int,
    receiver_user_id: int,
    exp_updates: dict,
) -> None:
    _queue_user_level_updates(
        background_tasks,
        db,
        sender_user_id,
        receiver_user_id,
    )
    _queue_room_level_and_rankings(
        background_tasks,
        db,
        room_id,
        sender_user_id,
        receiver_user_id,
        exp_updates,
    )

@router.get("/me", response_model=EconomyDashboardResponse)
def get_my_economy_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    data = economy_service.dashboard_for_user(db, current_user)
    return EconomyDashboardResponse(
        wallet=_wallet_response(db, data["wallet"]),
        seller_pool=_pool_response(data["seller_pool"]),
        merchant_pool=_pool_response(data["merchant_pool"]),
        gaming_pool=_pool_response(data["gaming_pool"]),
    )


@router.get("/users/public/{public_user_id}/summary")
def get_public_user_economy_summary(
    public_user_id: int,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
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
def send_gift(
    payload: GiftSendPublicRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    receiver = _receiver_from_public_id(db, payload.receiver_public_user_id)
    room = _room_from_public_id(db, payload.room_public_id)
    _require_room_gift_presence(db, room, current_user.id, receiver.id)
    catalog_gift = _catalog_gift_or_error(db, payload.gift_id, payload.quantity)
    if str(catalog_gift.get("gift_type") or "").lower() == "lucky":
        return _send_lucky_gift_authoritative(payload, current_user, db, background_tasks)
    coin_value = int(catalog_gift["coin_value"])
    room_id = room.id if room is not None else None

    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.settle_gift(
            request_id=request_id,
            sender_user_id=current_user.id,
            receiver_user_id=receiver.id,
            gift_id=payload.gift_id,
            coin_value=coin_value,
            quantity=payload.quantity,
            room_id=room_id,
            relationship_id=payload.relationship_id,
            is_relationship_gift=payload.is_relationship_gift,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    exp_updates = experience_service.apply_gift_exp(
        db,
        sender_user_id=current_user.id,
        receiver_user_id=receiver.id,
        room_id=room_id,
        send_exp=int(result.get("send_exp_amount") or 0),
        receive_exp=int(result.get("receive_exp_amount") or 0),
        room_exp=int(result.get("room_exp_amount") or 0),
        source_id=str(result["gift_transaction_id"]),
    )
    db.commit()
    result["experience_updates"] = exp_updates
    result["rule"] = (
        "Gift send committed. Sender coins debited; receiver rubies credited "
        "at 30%; Send/Receive/Room EXP updated instantly. Self gifting is allowed."
    )
    _queue_after_gift(
        background_tasks,
        db,
        room_id=room_id,
        sender_user_id=current_user.id,
        receiver_user_id=receiver.id,
        exp_updates=exp_updates,
    )
    _queue_room_gift_event(
        background_tasks,
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


def _send_lucky_gift_authoritative(
    payload: GiftSendPublicRequest,
    current_user: User,
    db: Session,
    background_tasks: BackgroundTasks,
):
    receiver = _receiver_from_public_id(db, payload.receiver_public_user_id)
    room = _room_from_public_id(db, payload.room_public_id)
    _require_room_gift_presence(db, room, current_user.id, receiver.id)
    catalog_gift = _catalog_gift_or_error(
        db,
        payload.gift_id,
        payload.quantity,
        require_lucky=True,
    )
    coin_value = int(catalog_gift["coin_value"])
    room_id = room.id if room is not None else None
    request_id = (payload.request_id or str(uuid4())).strip()

    try:
        result = economy_service_client.settle_lucky_gift(
            request_id=request_id,
            sender_user_id=current_user.id,
            receiver_user_id=receiver.id,
            gift_id=payload.gift_id,
            gift_name=str(
                catalog_gift.get("name")
                or payload.gift_id.replace("_", " ").title()
            ),
            coin_value=coin_value,
            quantity=payload.quantity,
            room_id=room_id,
            relationship_id=payload.relationship_id,
            is_relationship_gift=payload.is_relationship_gift,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    exp_updates = experience_service.apply_gift_exp(
        db,
        sender_user_id=current_user.id,
        receiver_user_id=receiver.id,
        room_id=room_id,
        send_exp=int(result.get("send_exp_amount") or 0),
        receive_exp=int(result.get("receive_exp_amount") or 0),
        room_exp=int(result.get("room_exp_amount") or 0),
        source_id=str(result["gift_transaction_id"]),
    )
    db.commit()
    result["experience_updates"] = exp_updates

    _queue_after_gift(
        background_tasks,
        db,
        room_id=room_id,
        sender_user_id=current_user.id,
        receiver_user_id=receiver.id,
        exp_updates=exp_updates,
    )
    _queue_room_gift_event(
        background_tasks,
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
