from __future__ import annotations

from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import EconomyDirection, EconomyPoolStatus, GamePool, GamePoolLedger, GamePoolType
from app.models.user import User
from app.services import jungle_hunt_props_runtime_service

GLOBAL_GAME_KEY = "__GLOBAL__"
MAIN_POOL_TYPE = GamePoolType.GAME_HOUSE_POOL.value
GAME_POOL_TYPE = GamePoolType.GAME_HOUSE_POOL.value

DEFAULT_MAIN_BALANCE = 100_000_000
DEFAULT_GAME_BALANCE = 25_000_000
DEFAULT_RESERVED_BALANCE = 0
DEFAULT_DAILY_PAYOUT_CAP = 30_000_000
DEFAULT_DAILY_LOSS_LIMIT = 15_000_000
DEFAULT_MAX_SINGLE_PAYOUT = 10_000_000
DEFAULT_RTP_TARGET_BPS = 8500
DEFAULT_MAIN_SAFE_RATIO_BPS = 6500
DEFAULT_GAME_SAFE_RATIO_BPS = 7500


def available_balance(pool: GamePool) -> int:
    return max(int(pool.balance or 0) - int(pool.reserved_balance or 0), 0)


def _pool_response(pool: GamePool) -> dict:
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


def get_or_create_pool(db: Session, game_key: str, pool_type: str = GAME_POOL_TYPE, *, commit: bool = True) -> GamePool:
    pool = db.query(GamePool).filter(GamePool.game_key == game_key, GamePool.pool_type == pool_type).first()
    if pool:
        return pool
    is_main = game_key == GLOBAL_GAME_KEY
    pool = GamePool(
        game_key=game_key,
        pool_type=pool_type,
        balance=DEFAULT_MAIN_BALANCE if is_main else DEFAULT_GAME_BALANCE,
        reserved_balance=DEFAULT_RESERVED_BALANCE,
        status=EconomyPoolStatus.ACTIVE.value,
        daily_payout_cap=DEFAULT_DAILY_PAYOUT_CAP,
        daily_loss_limit=DEFAULT_DAILY_LOSS_LIMIT,
        max_single_payout=DEFAULT_MAX_SINGLE_PAYOUT,
        rtp_target_basis_points=DEFAULT_RTP_TARGET_BPS,
    )
    db.add(pool)
    if commit:
        db.commit()
        db.refresh(pool)
    else:
        db.flush()
    return pool


def ensure_main_and_game_pools(
    db: Session,
    game_key: str,
    *,
    commit: bool = True,
) -> tuple[GamePool, GamePool]:
    main_pool = get_or_create_pool(
        db,
        GLOBAL_GAME_KEY,
        MAIN_POOL_TYPE,
        commit=commit,
    )
    game_pool = get_or_create_pool(
        db,
        game_key,
        GAME_POOL_TYPE,
        commit=commit,
    )
    return main_pool, game_pool


def list_pools(db: Session) -> list[dict]:
    pools = db.query(GamePool).order_by(GamePool.game_key.asc(), GamePool.id.asc()).all()
    return [_pool_response(pool) for pool in pools]


def get_pool_detail(db: Session, game_key: str) -> dict:
    main_pool, game_pool = ensure_main_and_game_pools(db, game_key)
    return {"main_pool": _pool_response(main_pool), "game_pool": _pool_response(game_pool)}


def _ledger(
    db: Session,
    pool: GamePool,
    direction: str,
    amount: int,
    source_type: str,
    actor: User | None,
    reason: str,
    round_id: int | None = None,
    user_id: int | None = None,
    source_id: str | None = None,
    metadata_json: str | None = None,
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
            round_id=round_id,
            user_id=user_id,
            created_by_user_id=actor.id if actor else None,
            reason=reason,
            metadata_json=metadata_json,
        )
    )


def adjust_pool(
    db: Session,
    actor: User,
    game_key: str,
    amount: int,
    direction: str,
    reason: str,
    pool_type: str = GAME_POOL_TYPE,
    *,
    commit: bool = True,
) -> GamePool:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    pool = get_or_create_pool(db, game_key, pool_type, commit=commit)
    if direction not in {EconomyDirection.CREDIT.value, EconomyDirection.DEBIT.value}:
        raise HTTPException(status_code=400, detail="Invalid direction")
    if direction == EconomyDirection.DEBIT.value and available_balance(pool) < amount:
        raise HTTPException(status_code=400, detail="Pool available balance is too low")
    _ledger(db, pool, direction, amount, "SUPER_OWNER_POOL_ADJUSTMENT", actor, reason)
    if direction == EconomyDirection.CREDIT.value:
        pool.balance += amount
    else:
        pool.balance -= amount
    if commit:
        db.commit()
        db.refresh(pool)
    else:
        db.flush()
    return pool


def update_pool_settings(
    db: Session,
    actor: User,
    game_key: str,
    pool_type: str,
    status: str | None,
    daily_payout_cap: int | None,
    daily_loss_limit: int | None,
    max_single_payout: int | None,
    rtp_target_basis_points: int | None,
    reason: str,
    *,
    commit: bool = True,
) -> GamePool:
    pool = get_or_create_pool(db, game_key, pool_type, commit=commit)
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
    _ledger(db, pool, EconomyDirection.CREDIT.value, 0, "SUPER_OWNER_POOL_SETTINGS", actor, reason)
    if commit:
        db.commit()
        db.refresh(pool)
    else:
        db.flush()
    return pool


def allocate_from_main_to_game(db: Session, actor: User, game_key: str, amount: int, reason: str, *, commit: bool = True) -> dict:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    main_pool, game_pool = ensure_main_and_game_pools(db, game_key, commit=commit)
    if available_balance(main_pool) < amount:
        raise HTTPException(status_code=400, detail="Main game house pool available balance is too low")
    _ledger(db, main_pool, EconomyDirection.DEBIT.value, amount, "POOL_ALLOCATE_TO_GAME", actor, reason, source_id=game_key)
    _ledger(db, game_pool, EconomyDirection.CREDIT.value, amount, "POOL_ALLOCATE_FROM_MAIN", actor, reason, source_id=GLOBAL_GAME_KEY)
    main_pool.balance -= amount
    game_pool.balance += amount
    if commit:
        db.commit()
        db.refresh(main_pool)
        db.refresh(game_pool)
    else:
        db.flush()
    return {"main_pool": _pool_response(main_pool), "game_pool": _pool_response(game_pool)}


def withdraw_from_game_to_main(db: Session, actor: User, game_key: str, amount: int, reason: str, *, commit: bool = True) -> dict:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    main_pool, game_pool = ensure_main_and_game_pools(db, game_key, commit=commit)
    if available_balance(game_pool) < amount:
        raise HTTPException(status_code=400, detail="Game pool available balance is too low")
    _ledger(db, game_pool, EconomyDirection.DEBIT.value, amount, "POOL_WITHDRAW_TO_MAIN", actor, reason, source_id=GLOBAL_GAME_KEY)
    _ledger(db, main_pool, EconomyDirection.CREDIT.value, amount, "POOL_WITHDRAW_FROM_GAME", actor, reason, source_id=game_key)
    game_pool.balance -= amount
    main_pool.balance += amount
    if commit:
        db.commit()
        db.refresh(main_pool)
        db.refresh(game_pool)
    else:
        db.flush()
    return {"main_pool": _pool_response(main_pool), "game_pool": _pool_response(game_pool)}


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


def _validate_exposure_base(
    db: Session,
    game_key: str,
    proposed_worst_payout: int,
    proposed_single_payout: int | None = None,
) -> tuple[bool, str, dict]:
    main_pool, game_pool = ensure_main_and_game_pools(db, game_key)
    proposed_single_payout = proposed_single_payout if proposed_single_payout is not None else proposed_worst_payout
    if main_pool.status != EconomyPoolStatus.ACTIVE.value:
        return False, "MAIN_GAME_POOL_FROZEN", {"main_pool": _pool_response(main_pool), "game_pool": _pool_response(game_pool)}
    if game_pool.status != EconomyPoolStatus.ACTIVE.value:
        return False, "GAME_POOL_FROZEN", {"main_pool": _pool_response(main_pool), "game_pool": _pool_response(game_pool)}
    if game_pool.max_single_payout and proposed_single_payout > game_pool.max_single_payout:
        return False, "GAME_MAX_SINGLE_PAYOUT", {"proposed_single_payout": proposed_single_payout, "game_pool": _pool_response(game_pool)}
    if main_pool.max_single_payout and proposed_single_payout > main_pool.max_single_payout:
        return False, "MAIN_MAX_SINGLE_PAYOUT", {"proposed_single_payout": proposed_single_payout, "main_pool": _pool_response(main_pool)}

    game_available = available_balance(game_pool)
    main_available = available_balance(main_pool)
    game_allowed = game_available * DEFAULT_GAME_SAFE_RATIO_BPS // 10_000
    main_allowed = main_available * DEFAULT_MAIN_SAFE_RATIO_BPS // 10_000
    if proposed_worst_payout > game_allowed:
        return False, "GAME_POOL_EXPOSURE_LIMIT", {"proposed_worst_payout": proposed_worst_payout, "game_allowed": game_allowed, "game_pool": _pool_response(game_pool)}
    if proposed_worst_payout > main_allowed:
        return False, "MAIN_POOL_EXPOSURE_LIMIT", {"proposed_worst_payout": proposed_worst_payout, "main_allowed": main_allowed, "main_pool": _pool_response(main_pool)}

    game_payout_today = _today_amount(db, game_pool.id, ["GAME_PAYOUT"], EconomyDirection.DEBIT.value)
    main_payout_today = _today_amount(db, main_pool.id, ["GAME_BACKSTOP_PAYOUT"], EconomyDirection.DEBIT.value)
    if game_pool.daily_payout_cap and game_payout_today + proposed_worst_payout > game_pool.daily_payout_cap:
        return False, "GAME_DAILY_PAYOUT_CAP", {"game_payout_today": game_payout_today, "proposed_worst_payout": proposed_worst_payout, "game_pool": _pool_response(game_pool)}
    if main_pool.daily_payout_cap and main_payout_today + proposed_worst_payout > main_pool.daily_payout_cap:
        return False, "MAIN_DAILY_PAYOUT_CAP", {"main_payout_today": main_payout_today, "proposed_worst_payout": proposed_worst_payout, "main_pool": _pool_response(main_pool)}

    return True, "ALLOW", {"main_pool": _pool_response(main_pool), "game_pool": _pool_response(game_pool), "proposed_worst_payout": proposed_worst_payout}


def record_bet_income(db: Session, game_key: str, round_id: int, user_id: int, amount: int, actor: User | None = None) -> None:
    _, game_pool = ensure_main_and_game_pools(db, game_key)
    _ledger(db, game_pool, EconomyDirection.CREDIT.value, amount, "GAME_BET_INCOME", actor, "Game bet income", round_id=round_id, user_id=user_id)
    game_pool.balance += amount


def record_payout(db: Session, game_key: str, round_id: int, user_id: int, amount: int, actor: User | None = None) -> None:
    main_pool, game_pool = ensure_main_and_game_pools(db, game_key)
    if amount <= 0:
        return
    if available_balance(game_pool) >= amount:
        _ledger(db, game_pool, EconomyDirection.DEBIT.value, amount, "GAME_PAYOUT", actor, "Game payout", round_id=round_id, user_id=user_id)
        game_pool.balance -= amount
        return
    game_part = available_balance(game_pool)
    if game_part > 0:
        _ledger(db, game_pool, EconomyDirection.DEBIT.value, game_part, "GAME_PAYOUT", actor, "Partial game payout", round_id=round_id, user_id=user_id)
        game_pool.balance -= game_part
    remaining = amount - game_part
    if available_balance(main_pool) < remaining:
        raise HTTPException(status_code=409, detail="Insufficient game house pool reserve for payout")
    _ledger(db, main_pool, EconomyDirection.DEBIT.value, remaining, "GAME_BACKSTOP_PAYOUT", actor, "Main pool backstop payout", round_id=round_id, user_id=user_id)
    main_pool.balance -= remaining


def get_testing_mode(db: Session, game_key: str) -> bool:
    return jungle_hunt_props_runtime_service.get_testing_mode(db, game_key)


def validate_exposure(
    db: Session,
    game_key: str,
    proposed_worst_payout: int,
    proposed_single_payout: int,
) -> tuple[bool, str, dict]:
    if get_testing_mode(db, game_key):
        return True, "TESTING_MODE_BYPASS", {
            "testing_mode_enabled": True,
            "game_key": game_key,
            "proposed_worst_payout": proposed_worst_payout,
            "proposed_single_payout": proposed_single_payout,
        }

    return _validate_exposure_base(
        db=db,
        game_key=game_key,
        proposed_worst_payout=proposed_worst_payout,
        proposed_single_payout=proposed_single_payout,
    )

