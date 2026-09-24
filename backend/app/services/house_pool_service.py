from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import GamePool, GamePoolLedger, GamePoolType, EconomyDirection
from app.models.economy_house_reservation import EconomyHouseReservation


@dataclass(frozen=True)
class HousePoolRiskSnapshot:
    house_pool_balance: int
    house_reserved_liability: int
    house_exposure: int
    max_payout_per_round: int
    daily_house_loss_limit: int
    risk_tier: str
    payout_pressure: float


def get_house_pool(db: Session, pool_type: str) -> GamePool | None:
    safe_pool_type = str(pool_type or GamePoolType.GAME_HOUSE_POOL.value)
    return db.query(GamePool).filter(GamePool.pool_type == safe_pool_type).first()


def reserve_house_liability(
    db: Session,
    pool_type: str,
    amount: int,
    reference_type: str,
    reference_id: str | None,
    *,
    reservation_key: str | None = None,
    release_scope: str | None = None,
    transaction_id: str | None = None,
    user_id: int | None = None,
) -> dict:
    safe_amount = max(int(amount or 0), 0)
    safe_pool_type = str(pool_type or GamePoolType.GAME_HOUSE_POOL.value)
    pool = (
        db.query(GamePool)
        .filter(GamePool.pool_type == safe_pool_type)
        .with_for_update()
        .first()
    )
    if pool is None or safe_amount <= 0:
        return {
            "reservation_id": None,
            "reservation_key": reservation_key,
            "release_scope": release_scope,
            "house_pool_balance": int(pool.balance) if pool else 0,
            "house_reserved_liability": int(pool.reserved_balance) if pool else 0,
            "reserved_amount": 0,
            "duplicate": False,
            "safe_default": True,
        }

    key = (reservation_key or f"{reference_type}:{reference_id or 'pending'}").strip()
    scope = (release_scope or reference_id or key).strip()
    if not key or not scope:
        raise HTTPException(status_code=400, detail="House reservation identity is required")

    existing = (
        db.query(EconomyHouseReservation)
        .filter(EconomyHouseReservation.reservation_key == key)
        .with_for_update()
        .first()
    )
    if existing is not None:
        if (
            int(existing.pool_id) != int(pool.id)
            or int(existing.amount) != safe_amount
            or existing.release_scope != scope
            or existing.reference_type != reference_type
        ):
            raise HTTPException(
                status_code=409,
                detail="House reservation key reused with different request",
            )
        return {
            "reservation_id": existing.id,
            "reservation_key": existing.reservation_key,
            "release_scope": existing.release_scope,
            "house_pool_balance": int(pool.balance or 0),
            "house_reserved_liability": int(pool.reserved_balance or 0),
            "reserved_amount": int(existing.amount),
            "duplicate": True,
            "safe_default": False,
        }

    available = max(int(pool.balance or 0) - int(pool.reserved_balance or 0), 0)
    if available < safe_amount:
        raise HTTPException(
            status_code=409,
            detail="Insufficient house pool available balance for reservation",
        )

    reservation = EconomyHouseReservation(
        reservation_key=key,
        release_scope=scope,
        pool_id=pool.id,
        user_id=user_id,
        amount=safe_amount,
        status="ACTIVE",
        reference_type=reference_type,
        reference_id=reference_id,
        transaction_id=transaction_id,
    )
    db.add(reservation)
    pool.reserved_balance = int(pool.reserved_balance or 0) + safe_amount
    db.flush()
    return {
        "reservation_id": reservation.id,
        "reservation_key": reservation.reservation_key,
        "release_scope": reservation.release_scope,
        "house_pool_balance": int(pool.balance or 0),
        "house_reserved_liability": int(pool.reserved_balance or 0),
        "reserved_amount": safe_amount,
        "duplicate": False,
        "safe_default": False,
    }


def release_house_liability(
    db: Session,
    release_scope: str | None,
) -> dict:
    scope = str(release_scope or "").strip()
    if not scope:
        return {
            "release_scope": scope,
            "released": False,
            "released_amount": 0,
            "reservation_count": 0,
            "safe_default": True,
        }

    reservations = (
        db.query(EconomyHouseReservation)
        .filter(
            EconomyHouseReservation.release_scope == scope,
            EconomyHouseReservation.status == "ACTIVE",
        )
        .order_by(EconomyHouseReservation.id.asc())
        .with_for_update()
        .all()
    )
    if not reservations:
        return {
            "release_scope": scope,
            "released": False,
            "released_amount": 0,
            "reservation_count": 0,
            "safe_default": True,
        }

    by_pool: dict[int, int] = {}
    for reservation in reservations:
        by_pool[int(reservation.pool_id)] = (
            by_pool.get(int(reservation.pool_id), 0) + int(reservation.amount)
        )

    for pool_id, released_amount in by_pool.items():
        pool = (
            db.query(GamePool)
            .filter(GamePool.id == pool_id)
            .with_for_update()
            .one()
        )
        current_reserved = int(pool.reserved_balance or 0)
        if current_reserved < released_amount:
            raise HTTPException(
                status_code=500,
                detail="House reservation ledger exceeds pool reserved balance",
            )
        pool.reserved_balance = current_reserved - released_amount

    released_at = datetime.utcnow()
    for reservation in reservations:
        reservation.status = "RELEASED"
        reservation.released_at = released_at

    db.flush()
    return {
        "release_scope": scope,
        "released": True,
        "released_amount": sum(int(item.amount) for item in reservations),
        "reservation_count": len(reservations),
        "safe_default": False,
    }


def record_house_profit_or_loss(
    db: Session,
    pool_type: str,
    amount: int,
    reference_type: str,
    reference_id: str | None,
) -> dict:
    safe_amount = int(amount or 0)
    pool = get_house_pool(db, pool_type)
    if pool is None or safe_amount == 0:
        return {"recorded": False, "house_profit_or_loss": safe_amount, "safe_default": True}

    before = int(pool.balance)
    pool.balance += safe_amount
    after = int(pool.balance)
    db.add(
        GamePoolLedger(
            pool_id=pool.id,
            direction=EconomyDirection.CREDIT.value if safe_amount > 0 else EconomyDirection.DEBIT.value,
            amount=abs(safe_amount),
            before_balance=before,
            after_balance=after,
            source_type=reference_type,
            source_id=reference_id,
            game_key=pool.game_key,
            reason="House profit/loss settlement",
        )
    )
    db.flush()
    return {"recorded": True, "pool_id": pool.id, "house_profit_or_loss": safe_amount, "house_pool_balance": after, "safe_default": False}


def calculate_payout_pressure(db: Session, pool_type: str) -> HousePoolRiskSnapshot:
    pool = get_house_pool(db, pool_type)
    if pool is None:
        return HousePoolRiskSnapshot(
            house_pool_balance=0,
            house_reserved_liability=0,
            house_exposure=0,
            max_payout_per_round=0,
            daily_house_loss_limit=0,
            risk_tier="low",
            payout_pressure=0.0,
        )
    balance = max(int(pool.balance or 0), 0)
    reserved = max(int(pool.reserved_balance or 0), 0)
    pressure = 0.0 if balance <= 0 else min(reserved / max(balance, 1), 1.0)
    risk_tier = "high" if pressure >= 0.75 else "medium" if pressure >= 0.35 else "low"
    return HousePoolRiskSnapshot(
        house_pool_balance=balance,
        house_reserved_liability=reserved,
        house_exposure=reserved,
        max_payout_per_round=int(pool.max_single_payout or 0),
        daily_house_loss_limit=int(pool.daily_loss_limit or 0),
        risk_tier=risk_tier,
        payout_pressure=pressure,
    )


def can_pay_reward(db: Session, pool_type: str, reward_amount: int) -> bool:
    safe_reward = max(int(reward_amount or 0), 0)
    snapshot = calculate_payout_pressure(db, pool_type)
    if snapshot.max_payout_per_round > 0 and safe_reward > snapshot.max_payout_per_round:
        return False
    if snapshot.house_pool_balance <= 0:
        return True
    return safe_reward <= max(snapshot.house_pool_balance - snapshot.house_reserved_liability, 0)


def cap_reward_by_house_rules(db: Session, pool_type: str, reward_amount: int) -> int:
    safe_reward = max(int(reward_amount or 0), 0)
    snapshot = calculate_payout_pressure(db, pool_type)
    capped = safe_reward
    if snapshot.max_payout_per_round > 0:
        capped = min(capped, snapshot.max_payout_per_round)
    if snapshot.house_pool_balance > 0:
        capped = min(capped, max(snapshot.house_pool_balance - snapshot.house_reserved_liability, 0))
    return max(capped, 0)
