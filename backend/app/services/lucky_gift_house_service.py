from __future__ import annotations

import json
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import EconomyDirection, EconomyPoolStatus, GamePool, GamePoolLedger, GamePoolType
from app.models.user import User
from app.services import lucky_gift_props_service

GLOBAL_POOL_KEY = "__GLOBAL__"
LUCKY_GIFT_KEY = lucky_gift_props_service.LUCKY_GIFT_KEY
POOL_TYPE = GamePoolType.GAME_HOUSE_POOL.value

DEFAULT_MAIN_BALANCE = 100_000_000
DEFAULT_LUCKY_BALANCE = 25_000_000
DEFAULT_DAILY_PAYOUT_CAP = 30_000_000
DEFAULT_DAILY_LOSS_LIMIT = 15_000_000
DEFAULT_MAX_SINGLE_PAYOUT = 10_000_000
DEFAULT_RTP_TARGET_BPS = 8500


def available_balance(pool: GamePool) -> int:
    return max(int(pool.balance or 0) - int(pool.reserved_balance or 0), 0)


def pool_response(pool: GamePool) -> dict:
    return {
        "id": pool.id,
        "game_key": pool.game_key,
        "pool_type": pool.pool_type,
        "balance": pool.balance,
        "reserved_balance": pool.reserved_balance,
        "available_balance": available_balance(pool),
        "status": pool.status,
        "daily_payout_cap": pool.daily_payout_cap,
        "daily_loss_limit": pool.daily_loss_limit,
        "max_single_payout": pool.max_single_payout,
        "rtp_target_basis_points": pool.rtp_target_basis_points,
        "created_at": pool.created_at,
        "updated_at": pool.updated_at,
    }


def get_or_create_pool(db: Session, game_key: str, pool_type: str = POOL_TYPE) -> GamePool:
    pool = db.query(GamePool).filter(GamePool.game_key == game_key, GamePool.pool_type == pool_type).first()
    if pool:
        return pool
    is_main = game_key == GLOBAL_POOL_KEY
    pool = GamePool(
        game_key=game_key,
        pool_type=pool_type,
        balance=DEFAULT_MAIN_BALANCE if is_main else DEFAULT_LUCKY_BALANCE,
        reserved_balance=0,
        status=EconomyPoolStatus.ACTIVE.value,
        daily_payout_cap=DEFAULT_DAILY_PAYOUT_CAP,
        daily_loss_limit=DEFAULT_DAILY_LOSS_LIMIT,
        max_single_payout=DEFAULT_MAX_SINGLE_PAYOUT,
        rtp_target_basis_points=DEFAULT_RTP_TARGET_BPS,
    )
    db.add(pool)
    db.flush()
    return pool


def ensure_house_pools(db: Session, *, commit: bool = False) -> tuple[GamePool, GamePool]:
    main_pool = get_or_create_pool(db, GLOBAL_POOL_KEY)
    lucky_pool = get_or_create_pool(db, LUCKY_GIFT_KEY)
    if commit:
        db.commit()
        db.refresh(main_pool)
        db.refresh(lucky_pool)
    return main_pool, lucky_pool


def list_pools(db: Session) -> list[dict]:
    ensure_house_pools(db, commit=True)
    pools = db.query(GamePool).filter(GamePool.game_key.in_([GLOBAL_POOL_KEY, LUCKY_GIFT_KEY])).order_by(GamePool.game_key.asc(), GamePool.id.asc()).all()
    return [pool_response(pool) for pool in pools]


def get_pool_detail(db: Session) -> dict:
    main_pool, lucky_pool = ensure_house_pools(db, commit=True)
    return {"main_pool": pool_response(main_pool), "lucky_pool": pool_response(lucky_pool)}


def _ledger(
    db: Session,
    pool: GamePool,
    direction: str,
    amount: int,
    source_type: str,
    actor: User | None,
    reason: str,
    *,
    user_id: int | None = None,
    source_id: str | None = None,
    metadata: dict | None = None,
) -> None:
    before = int(pool.balance or 0)
    after = before + amount if direction == EconomyDirection.CREDIT.value else before - amount
    db.add(
        GamePoolLedger(
            pool_id=pool.id,
            direction=direction,
            amount=amount,
            before_balance=before,
            after_balance=after,
            source_type=source_type,
            source_id=source_id,
            game_key=pool.game_key,
            user_id=user_id,
            created_by_user_id=actor.id if actor else None,
            reason=reason,
            metadata_json=json.dumps(metadata or {}, separators=(",", ":")),
        )
    )


def _assert_active(pool: GamePool, label: str) -> None:
    if pool.status != EconomyPoolStatus.ACTIVE.value:
        raise HTTPException(status_code=409, detail=f"{label} lucky gift house pool is not active")


def _today_amount(db: Session, pool_id: int, source_types: list[str], direction: str) -> int:
    since = datetime.utcnow() - timedelta(hours=24)
    return int(
        db.query(func.coalesce(func.sum(GamePoolLedger.amount), 0))
        .filter(
            GamePoolLedger.pool_id == pool_id,
            GamePoolLedger.direction == direction,
            GamePoolLedger.source_type.in_(source_types),
            GamePoolLedger.created_at >= since,
        )
        .scalar()
        or 0
    )


def validate_payout_exposure(db: Session, *, payout_amount: int) -> dict:
    main_pool, lucky_pool = ensure_house_pools(db)
    safe_payout = max(int(payout_amount or 0), 0)
    if safe_payout <= 0:
        return {"allowed": True, "reason": "NO_PAYOUT", "main_pool": pool_response(main_pool), "lucky_pool": pool_response(lucky_pool)}

    _assert_active(main_pool, "Main")
    _assert_active(lucky_pool, "Lucky")
    props = lucky_gift_props_service.get_props(db)
    safe_ratio = int(props.get("payout_pool_safe_ratio_basis_points", 6500))

    if lucky_pool.max_single_payout and safe_payout > lucky_pool.max_single_payout:
        raise HTTPException(status_code=409, detail="Lucky gift payout exceeds max single payout")
    if main_pool.max_single_payout and safe_payout > main_pool.max_single_payout:
        raise HTTPException(status_code=409, detail="Lucky gift payout exceeds main pool max single payout")

    lucky_allowed = available_balance(lucky_pool) * safe_ratio // 10_000
    main_allowed = available_balance(main_pool) * safe_ratio // 10_000
    if safe_payout > max(lucky_allowed + main_allowed, available_balance(lucky_pool)):
        raise HTTPException(status_code=409, detail="Lucky gift house pool exposure is too high")

    lucky_payout_today = _today_amount(db, lucky_pool.id, ["LUCKY_GIFT_PAYOUT"], EconomyDirection.DEBIT.value)
    main_payout_today = _today_amount(db, main_pool.id, ["LUCKY_GIFT_BACKSTOP_PAYOUT"], EconomyDirection.DEBIT.value)
    if lucky_pool.daily_payout_cap and lucky_payout_today + safe_payout > lucky_pool.daily_payout_cap:
        raise HTTPException(status_code=409, detail="Lucky gift daily payout cap reached")
    if main_pool.daily_payout_cap and main_payout_today + safe_payout > main_pool.daily_payout_cap:
        raise HTTPException(status_code=409, detail="Main lucky gift backstop daily payout cap reached")

    return {"allowed": True, "reason": "ALLOW", "main_pool": pool_response(main_pool), "lucky_pool": pool_response(lucky_pool)}


def record_spend_income(db: Session, *, amount: int, actor: User, source_id: str, user_id: int, metadata: dict | None = None) -> None:
    if amount <= 0:
        return
    _, lucky_pool = ensure_house_pools(db)
    _assert_active(lucky_pool, "Lucky")
    _ledger(db, lucky_pool, EconomyDirection.CREDIT.value, amount, "LUCKY_GIFT_SPEND_INCOME", actor, "Lucky gift spend income", user_id=user_id, source_id=source_id, metadata=metadata)
    lucky_pool.balance += amount


def record_payout(db: Session, *, amount: int, actor: User, source_id: str, user_id: int, metadata: dict | None = None) -> None:
    if amount <= 0:
        return
    main_pool, lucky_pool = ensure_house_pools(db)
    _assert_active(main_pool, "Main")
    _assert_active(lucky_pool, "Lucky")
    remaining = int(amount)

    lucky_part = min(available_balance(lucky_pool), remaining)
    if lucky_part > 0:
        _ledger(db, lucky_pool, EconomyDirection.DEBIT.value, lucky_part, "LUCKY_GIFT_PAYOUT", actor, "Lucky gift payout", user_id=user_id, source_id=source_id, metadata=metadata)
        lucky_pool.balance -= lucky_part
        remaining -= lucky_part
    if remaining <= 0:
        return
    if available_balance(main_pool) < remaining:
        raise HTTPException(status_code=409, detail="Insufficient lucky gift house pool reserve")
    _ledger(db, main_pool, EconomyDirection.DEBIT.value, remaining, "LUCKY_GIFT_BACKSTOP_PAYOUT", actor, "Main pool lucky gift backstop payout", user_id=user_id, source_id=source_id, metadata=metadata)
    main_pool.balance -= remaining


def adjust_pool(db: Session, *, actor: User, game_key: str, pool_type: str, direction: str, amount: int, reason: str) -> GamePool:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    pool = get_or_create_pool(db, game_key, pool_type)
    if direction not in {EconomyDirection.CREDIT.value, EconomyDirection.DEBIT.value}:
        raise HTTPException(status_code=400, detail="Invalid direction")
    if direction == EconomyDirection.DEBIT.value and available_balance(pool) < amount:
        raise HTTPException(status_code=400, detail="Pool available balance is too low")
    _ledger(db, pool, direction, amount, "SUPER_OWNER_LUCKY_POOL_ADJUSTMENT", actor, reason)
    if direction == EconomyDirection.CREDIT.value:
        pool.balance += amount
    else:
        pool.balance -= amount
    db.commit()
    db.refresh(pool)
    return pool


def allocate_main_to_lucky(db: Session, *, actor: User, amount: int, reason: str) -> dict:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    main_pool, lucky_pool = ensure_house_pools(db)
    if available_balance(main_pool) < amount:
        raise HTTPException(status_code=400, detail="Main pool available balance is too low")
    _ledger(db, main_pool, EconomyDirection.DEBIT.value, amount, "LUCKY_POOL_ALLOCATE_TO_GAME", actor, reason, source_id=LUCKY_GIFT_KEY)
    _ledger(db, lucky_pool, EconomyDirection.CREDIT.value, amount, "LUCKY_POOL_ALLOCATE_FROM_MAIN", actor, reason, source_id=GLOBAL_POOL_KEY)
    main_pool.balance -= amount
    lucky_pool.balance += amount
    db.commit()
    db.refresh(main_pool)
    db.refresh(lucky_pool)
    return {"main_pool": pool_response(main_pool), "lucky_pool": pool_response(lucky_pool)}


def withdraw_lucky_to_main(db: Session, *, actor: User, amount: int, reason: str) -> dict:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    main_pool, lucky_pool = ensure_house_pools(db)
    if available_balance(lucky_pool) < amount:
        raise HTTPException(status_code=400, detail="Lucky pool available balance is too low")
    _ledger(db, lucky_pool, EconomyDirection.DEBIT.value, amount, "LUCKY_POOL_WITHDRAW_TO_MAIN", actor, reason, source_id=GLOBAL_POOL_KEY)
    _ledger(db, main_pool, EconomyDirection.CREDIT.value, amount, "LUCKY_POOL_WITHDRAW_FROM_GAME", actor, reason, source_id=LUCKY_GIFT_KEY)
    lucky_pool.balance -= amount
    main_pool.balance += amount
    db.commit()
    db.refresh(main_pool)
    db.refresh(lucky_pool)
    return {"main_pool": pool_response(main_pool), "lucky_pool": pool_response(lucky_pool)}


def update_pool_settings(
    db: Session,
    *,
    actor: User,
    game_key: str,
    pool_type: str,
    status: str | None,
    daily_payout_cap: int | None,
    daily_loss_limit: int | None,
    max_single_payout: int | None,
    rtp_target_basis_points: int | None,
    reason: str,
) -> GamePool:
    pool = get_or_create_pool(db, game_key, pool_type)
    if status is not None:
        if status not in {item.value for item in EconomyPoolStatus}:
            raise HTTPException(status_code=400, detail="Invalid pool status")
        pool.status = status
    if daily_payout_cap is not None:
        pool.daily_payout_cap = daily_payout_cap
    if daily_loss_limit is not None:
        pool.daily_loss_limit = daily_loss_limit
    if max_single_payout is not None:
        pool.max_single_payout = max_single_payout
    if rtp_target_basis_points is not None:
        pool.rtp_target_basis_points = rtp_target_basis_points
    _ledger(db, pool, EconomyDirection.CREDIT.value, 0, "SUPER_OWNER_LUCKY_POOL_SETTINGS", actor, reason)
    db.commit()
    db.refresh(pool)
    return pool
