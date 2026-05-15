from typing import Any

from fastapi import APIRouter, Body, Depends
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyPoolStatus, GamePool, GamePoolType
from app.models.user import User
from app.schemas.game_props import (
    JungleHuntPropsResponse,
    LuckyGiftHousePoolResponse,
    LuckyGiftHousePoolUpdateRequest,
    LuckyGiftPropsResponse,
)
from app.services import house_pool_service, jungle_hunt_props_runtime_service, lucky_gift_props_service
from app.services.audit_log_service import create_admin_log

router = APIRouter(prefix="/super-owner/game-props", tags=["Super Owner Game Props"])

LUCKY_GIFT_POOL_KEY = "lucky_gifts"
LUCKY_GIFT_POOL_TYPE = GamePoolType.GAME_HOUSE_POOL.value


@router.get("/jungle-hunt", response_model=JungleHuntPropsResponse)
def get_jungle_hunt_props(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    return JungleHuntPropsResponse(**jungle_hunt_props_runtime_service.get_props(db))


@router.post("/jungle-hunt", response_model=JungleHuntPropsResponse)
def update_jungle_hunt_props(
    payload: dict[str, Any] = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    result = jungle_hunt_props_runtime_service.update_props(db, current_user, payload)

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_JUNGLE_HUNT_PROPS_UPDATED",
        resource_type="game_props",
        resource_id="jungle_hunt",
        reason=str(payload.get("reason") or "Super Owner Jungle Hunt props update"),
        metadata_json={
            "testing_mode_enabled": result["testing_mode_enabled"],
            "max_round_liability": result["max_round_liability"],
            "max_target_liability": result["max_target_liability"],
            "max_total_bet_per_round": result["max_total_bet_per_round"],
        },
    )

    return JungleHuntPropsResponse(**result)


@router.get("/lucky-gifts", response_model=LuckyGiftPropsResponse)
def get_lucky_gift_props(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    return LuckyGiftPropsResponse(**lucky_gift_props_service.get_props(db))


@router.post("/lucky-gifts", response_model=LuckyGiftPropsResponse)
def update_lucky_gift_props(
    payload: dict[str, Any] = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    result = lucky_gift_props_service.update_props(db, current_user, payload)

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_PROPS_UPDATED",
        resource_type="game_props",
        resource_id="lucky_gifts",
        reason=str(payload.get("reason") or "Super Owner lucky gift props update"),
        metadata_json={
            "testing_mode_enabled": result["testing_mode_enabled"],
            "payout_pool_safe_ratio_basis_points": result["payout_pool_safe_ratio_basis_points"],
            "whale_daily_spend": result["whale_daily_spend"],
            "whale_single_spend": result["whale_single_spend"],
            "manual_review_score": result["manual_review_score"],
            "block_score": result["block_score"],
            "multipliers": result["multipliers"],
        },
    )

    return LuckyGiftPropsResponse(**result)


def _get_or_create_lucky_gift_house_pool(db: Session) -> GamePool:
    pool = (
        db.query(GamePool)
        .filter(GamePool.game_key == LUCKY_GIFT_POOL_KEY, GamePool.pool_type == LUCKY_GIFT_POOL_TYPE)
        .first()
    )
    if pool is not None:
        return pool
    pool = GamePool(
        game_key=LUCKY_GIFT_POOL_KEY,
        pool_type=LUCKY_GIFT_POOL_TYPE,
        balance=0,
        reserved_balance=0,
        status=EconomyPoolStatus.ACTIVE.value,
        daily_payout_cap=0,
        daily_loss_limit=0,
        max_single_payout=0,
        rtp_target_basis_points=8000,
    )
    db.add(pool)
    db.commit()
    db.refresh(pool)
    return pool


def _lucky_gift_pool_payload(db: Session, pool: GamePool) -> dict[str, Any]:
    snapshot = house_pool_service.calculate_payout_pressure(db, LUCKY_GIFT_POOL_TYPE)
    # calculate_payout_pressure reads by pool_type only; prefer the lucky_gifts row values for CP display.
    balance = int(pool.balance or 0)
    reserved = int(pool.reserved_balance or 0)
    pressure = 0.0 if balance <= 0 else min(reserved / max(balance, 1), 1.0)
    risk_tier = "high" if pressure >= 0.75 else "medium" if pressure >= 0.35 else "low"
    return {
        "game_key": pool.game_key,
        "pool_type": pool.pool_type,
        "house_pool_balance": balance,
        "house_reserved_liability": reserved,
        "house_exposure": reserved,
        "max_payout_per_round": int(pool.max_single_payout or snapshot.max_payout_per_round or 0),
        "daily_house_loss_limit": int(pool.daily_loss_limit or snapshot.daily_house_loss_limit or 0),
        "risk_tier": risk_tier,
        "payout_pressure": pressure,
        "rtp_target_basis_points": int(pool.rtp_target_basis_points or 8000),
        "status": pool.status,
    }


@router.get("/lucky-gifts/house-pool", response_model=LuckyGiftHousePoolResponse)
def get_lucky_gift_house_pool(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    pool = _get_or_create_lucky_gift_house_pool(db)
    return LuckyGiftHousePoolResponse(**_lucky_gift_pool_payload(db, pool))


@router.post("/lucky-gifts/house-pool", response_model=LuckyGiftHousePoolResponse)
def update_lucky_gift_house_pool(
    payload: LuckyGiftHousePoolUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    pool = _get_or_create_lucky_gift_house_pool(db)

    if payload.balance is not None:
        pool.balance = int(payload.balance)
    if payload.reserved_balance is not None:
        pool.reserved_balance = int(payload.reserved_balance)
    if payload.max_payout_per_round is not None:
        pool.max_single_payout = int(payload.max_payout_per_round)
    if payload.daily_house_loss_limit is not None:
        pool.daily_loss_limit = int(payload.daily_house_loss_limit)
        pool.daily_payout_cap = int(payload.daily_house_loss_limit)
    if payload.rtp_target_basis_points is not None:
        pool.rtp_target_basis_points = int(payload.rtp_target_basis_points)
    if payload.status is not None:
        pool.status = payload.status.upper()

    db.commit()
    db.refresh(pool)
    result = _lucky_gift_pool_payload(db, pool)

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_HOUSE_POOL_UPDATED",
        resource_type="game_pool",
        resource_id=f"{pool.game_key}:{pool.pool_type}",
        reason=payload.reason,
        metadata_json=result,
    )

    return LuckyGiftHousePoolResponse(**result)
