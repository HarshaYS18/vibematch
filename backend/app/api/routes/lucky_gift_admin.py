from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, Body, Depends
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy_stats import LuckyGiftTransaction
from app.models.user import User
from app.schemas.game_pools import GamePoolResponse
from app.schemas.lucky_gifts_admin import (
    LuckyGiftModerationResponse,
    LuckyGiftModerationTransaction,
    LuckyGiftPoolAdjustRequest,
    LuckyGiftPoolPairResponse,
    LuckyGiftPoolSettingsRequest,
    LuckyGiftPoolTransferRequest,
    LuckyGiftPropsResponse,
)
from app.services import lucky_gift_house_service, lucky_gift_props_service
from app.services.audit_log_service import create_admin_log

router = APIRouter(prefix="/super-owner/lucky-gifts", tags=["Super Owner Lucky Gifts"])


def _metadata(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
    except Exception:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _transaction_payload(row: LuckyGiftTransaction) -> LuckyGiftModerationTransaction:
    return LuckyGiftModerationTransaction(
        transaction_id=row.id,
        sender_user_id=row.sender_user_id,
        receiver_user_id=row.receiver_user_id,
        room_id=row.room_id,
        gift_id=row.gift_id,
        gift_name=row.gift_name,
        spent_coins=row.spent_coins,
        multiplier=row.multiplier,
        reward_coins=row.reward_coins,
        net_win_coins=row.net_win_coins,
        is_big_win=row.is_big_win,
        metadata=_metadata(row.metadata_json),
        created_at=row.created_at,
    )


@router.get("/props", response_model=LuckyGiftPropsResponse)
def get_lucky_gift_props(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    return LuckyGiftPropsResponse(**lucky_gift_props_service.get_props(db))


@router.post("/props", response_model=LuckyGiftPropsResponse)
def update_lucky_gift_props(payload: dict[str, Any] = Body(...), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    result = lucky_gift_props_service.update_props(db, current_user, payload)
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_PROPS_UPDATED",
        resource_type="lucky_gift_props",
        resource_id="lucky_gifts",
        reason=str(payload.get("reason") or "Super Owner lucky gift props update"),
        metadata_json={
            "testing_mode_enabled": result["testing_mode_enabled"],
            "whale_single_spend": result["whale_single_spend"],
            "whale_daily_spend": result["whale_daily_spend"],
            "payout_pool_safe_ratio_basis_points": result["payout_pool_safe_ratio_basis_points"],
        },
    )
    return LuckyGiftPropsResponse(**result)


@router.get("/moderation", response_model=LuckyGiftModerationResponse)
def get_lucky_gift_moderation(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    house = LuckyGiftPoolPairResponse(**lucky_gift_house_service.get_pool_detail(db))
    props = LuckyGiftPropsResponse(**lucky_gift_props_service.get_props(db))
    latest = db.query(LuckyGiftTransaction).order_by(LuckyGiftTransaction.id.desc()).limit(30).all()
    high_risk = (
        db.query(LuckyGiftTransaction)
        .filter((LuckyGiftTransaction.multiplier >= 100) | (LuckyGiftTransaction.reward_coins >= props.broadcast_min_reward))
        .order_by(LuckyGiftTransaction.id.desc())
        .limit(30)
        .all()
    )
    return LuckyGiftModerationResponse(
        props=props,
        house_pools=house,
        latest_transactions=[_transaction_payload(row) for row in latest],
        high_risk_transactions=[_transaction_payload(row) for row in high_risk],
    )


@router.get("/house-pool", response_model=LuckyGiftPoolPairResponse)
def get_lucky_gift_house_pool(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    return LuckyGiftPoolPairResponse(**lucky_gift_house_service.get_pool_detail(db))


@router.get("/house-pool/list", response_model=list[GamePoolResponse])
def list_lucky_gift_house_pools(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    return [GamePoolResponse(**item) for item in lucky_gift_house_service.list_pools(db)]


@router.post("/house-pool/adjust", response_model=GamePoolResponse)
def adjust_lucky_gift_house_pool(payload: LuckyGiftPoolAdjustRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    pool = lucky_gift_house_service.adjust_pool(db=db, actor=current_user, game_key=payload.game_key, pool_type=payload.pool_type, direction=payload.direction, amount=payload.amount, reason=payload.reason)
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_ADJUSTED",
        resource_type="lucky_gift_house_pool",
        resource_id=str(pool.id),
        reason=payload.reason,
        metadata_json={"game_key": payload.game_key, "pool_type": payload.pool_type, "direction": payload.direction, "amount": payload.amount},
    )
    return GamePoolResponse(**lucky_gift_house_service.pool_response(pool))


@router.post("/house-pool/allocate", response_model=LuckyGiftPoolPairResponse)
def allocate_lucky_gift_house_pool(payload: LuckyGiftPoolTransferRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    result = lucky_gift_house_service.allocate_main_to_lucky(db=db, actor=current_user, amount=payload.amount, reason=payload.reason)
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_ALLOCATED",
        resource_type="lucky_gift_house_pool",
        reason=payload.reason,
        metadata_json={"game_key": "lucky_gifts", "amount": payload.amount, "direction": "MAIN_TO_LUCKY"},
    )
    return LuckyGiftPoolPairResponse(**result)


@router.post("/house-pool/withdraw", response_model=LuckyGiftPoolPairResponse)
def withdraw_lucky_gift_house_pool(payload: LuckyGiftPoolTransferRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    result = lucky_gift_house_service.withdraw_lucky_to_main(db=db, actor=current_user, amount=payload.amount, reason=payload.reason)
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_WITHDRAWN",
        resource_type="lucky_gift_house_pool",
        reason=payload.reason,
        metadata_json={"game_key": "lucky_gifts", "amount": payload.amount, "direction": "LUCKY_TO_MAIN"},
    )
    return LuckyGiftPoolPairResponse(**result)


@router.post("/house-pool/settings", response_model=GamePoolResponse)
def update_lucky_gift_house_pool_settings(payload: LuckyGiftPoolSettingsRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    pool = lucky_gift_house_service.update_pool_settings(
        db=db,
        actor=current_user,
        game_key=payload.game_key,
        pool_type=payload.pool_type,
        status=payload.status,
        daily_payout_cap=payload.daily_payout_cap,
        daily_loss_limit=payload.daily_loss_limit,
        max_single_payout=payload.max_single_payout,
        rtp_target_basis_points=payload.rtp_target_basis_points,
        reason=payload.reason,
    )
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_SETTINGS_UPDATED",
        resource_type="lucky_gift_house_pool",
        resource_id=str(pool.id),
        reason=payload.reason,
        metadata_json={
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
            "status": payload.status,
            "daily_payout_cap": payload.daily_payout_cap,
            "daily_loss_limit": payload.daily_loss_limit,
            "max_single_payout": payload.max_single_payout,
            "rtp_target_basis_points": payload.rtp_target_basis_points,
        },
    )
    return GamePoolResponse(**lucky_gift_house_service.pool_response(pool))
