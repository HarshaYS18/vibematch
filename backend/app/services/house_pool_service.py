from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.models.economy import GamePool, GamePoolLedger, GamePoolType, EconomyDirection


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
) -> dict:
    safe_amount = max(int(amount or 0), 0)
    pool = get_house_pool(db, pool_type)
    if pool is None or safe_amount <= 0:
        return {
            "reservation_id": None,
            "house_pool_balance": int(pool.balance) if pool else 0,
            "house_reserved_liability": int(pool.reserved_balance) if pool else 0,
            "reserved_amount": 0,
            "safe_default": True,
        }
    pool.reserved_balance += safe_amount
    db.flush()
    return {
        "reservation_id": f"{reference_type}:{reference_id or 'pending'}",
        "house_pool_balance": int(pool.balance),
        "house_reserved_liability": int(pool.reserved_balance),
        "reserved_amount": safe_amount,
        "safe_default": False,
    }


def release_house_liability(db: Session, reservation_id: str | None) -> dict:
    # Durable reservation rows are intentionally not introduced yet.
    # This placeholder keeps the settlement flow stable until full house-pool tables are hardened.
    return {"reservation_id": reservation_id, "released": True, "safe_default": True}


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
    return {"recorded": True, "house_profit_or_loss": safe_amount, "house_pool_balance": after, "safe_default": False}


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
