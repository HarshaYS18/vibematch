from __future__ import annotations

from dataclasses import dataclass

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.economy import (
    CoinPoolLedgerDirection,
    CoinPoolLedgerEntry,
    CoinPoolLedgerSource,
    CoinPoolType,
    CoinSupplyPool,
)
from app.models.role import RoleName
from app.models.user import User
from app.services import role_service


POOL_ROLE_MAP: dict[CoinPoolType, set[RoleName]] = {
    CoinPoolType.FOUNDER_SUPPLY: {RoleName.FOUNDER_OWNER},
    CoinPoolType.MERCHANT: {RoleName.MERCHANT, RoleName.OWNER, RoleName.FOUNDER_OWNER},
    CoinPoolType.COIN_SELLER: {RoleName.COIN_SELLER, RoleName.OWNER, RoleName.FOUNDER_OWNER},
    CoinPoolType.RESELLER: {RoleName.RESELLER, RoleName.OWNER, RoleName.FOUNDER_OWNER},
    CoinPoolType.AGENCY: {RoleName.AGENCY_OWNER, RoleName.OWNER, RoleName.FOUNDER_OWNER},
}


@dataclass(frozen=True)
class PoolMoveResult:
    pool: CoinSupplyPool
    ledger_entry: CoinPoolLedgerEntry


def require_founder_or_owner(actor: User) -> None:
    if not role_service.is_owner_or_above(actor):
        raise HTTPException(status_code=403, detail="Founder Owner or Owner permission required")


def user_allowed_pool_types(user: User) -> set[CoinPoolType]:
    role = role_service.get_primary_role(user)
    allowed: set[CoinPoolType] = set()
    for pool_type, roles in POOL_ROLE_MAP.items():
        if role in roles:
            allowed.add(pool_type)
    return allowed


def get_or_create_coin_pool(
    db: Session,
    *,
    pool_type: CoinPoolType,
    owner_user_id: int | None,
    seed_balance: int = 0,
) -> CoinSupplyPool:
    pool = (
        db.query(CoinSupplyPool)
        .filter(CoinSupplyPool.pool_type == pool_type, CoinSupplyPool.owner_user_id == owner_user_id)
        .first()
    )
    if pool:
        return pool

    pool = CoinSupplyPool(
        pool_type=pool_type,
        owner_user_id=owner_user_id,
        coin_balance=seed_balance,
        lifetime_coin_in=seed_balance,
        lifetime_coin_out=0,
        is_active=True,
        is_locked=False,
    )
    db.add(pool)
    db.flush()
    if seed_balance > 0:
        db.add(
            CoinPoolLedgerEntry(
                pool_id=pool.id,
                actor_user_id=owner_user_id,
                direction=CoinPoolLedgerDirection.CREDIT,
                source=CoinPoolLedgerSource.FOUNDER_MINT,
                amount=seed_balance,
                balance_before=0,
                balance_after=seed_balance,
                reference_type="pool_seed",
                reference_id=f"{pool_type.value}:{owner_user_id or 'platform'}",
                idempotency_key=f"pool_seed:{pool_type.value}:{owner_user_id or 'platform'}",
                reason="Initial pool seed",
                metadata_json={"seed": True},
            )
        )
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        pool = (
            db.query(CoinSupplyPool)
            .filter(CoinSupplyPool.pool_type == pool_type, CoinSupplyPool.owner_user_id == owner_user_id)
            .first()
        )
        if pool:
            return pool
        raise
    return pool


def get_founder_supply_pool(db: Session) -> CoinSupplyPool:
    return get_or_create_coin_pool(
        db,
        pool_type=CoinPoolType.FOUNDER_SUPPLY,
        owner_user_id=None,
        seed_balance=0,
    )


def move_pool_balance(
    db: Session,
    *,
    pool: CoinSupplyPool,
    direction: CoinPoolLedgerDirection,
    source: CoinPoolLedgerSource,
    amount: int,
    idempotency_key: str,
    actor_user_id: int | None = None,
    counterparty_user_id: int | None = None,
    related_pool_id: int | None = None,
    reference_type: str | None = None,
    reference_id: str | None = None,
    reason: str | None = None,
    metadata_json: dict | None = None,
) -> PoolMoveResult:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Pool amount must be greater than zero")

    existing = db.query(CoinPoolLedgerEntry).filter(CoinPoolLedgerEntry.idempotency_key == idempotency_key).first()
    if existing:
        existing_pool = db.query(CoinSupplyPool).filter(CoinSupplyPool.id == existing.pool_id).first()
        if not existing_pool:
            raise HTTPException(status_code=500, detail="Coin pool ledger is inconsistent")
        return PoolMoveResult(pool=existing_pool, ledger_entry=existing)

    locked_pool = db.query(CoinSupplyPool).filter(CoinSupplyPool.id == pool.id).with_for_update().first()
    if not locked_pool:
        raise HTTPException(status_code=404, detail="Coin pool not found")
    if not locked_pool.is_active:
        raise HTTPException(status_code=403, detail="Coin pool is inactive")
    if locked_pool.is_locked:
        raise HTTPException(status_code=403, detail=locked_pool.lock_reason or "Coin pool is locked")

    balance_before = locked_pool.coin_balance
    if direction == CoinPoolLedgerDirection.DEBIT:
        if balance_before < amount:
            raise HTTPException(status_code=400, detail="Insufficient coin pool balance")
        balance_after = balance_before - amount
        locked_pool.lifetime_coin_out += amount
    else:
        balance_after = balance_before + amount
        locked_pool.lifetime_coin_in += amount

    locked_pool.coin_balance = balance_after
    entry = CoinPoolLedgerEntry(
        pool_id=locked_pool.id,
        actor_user_id=actor_user_id,
        counterparty_user_id=counterparty_user_id,
        related_pool_id=related_pool_id,
        direction=direction,
        source=source,
        amount=amount,
        balance_before=balance_before,
        balance_after=balance_after,
        reference_type=reference_type,
        reference_id=reference_id,
        idempotency_key=idempotency_key,
        reason=reason,
        metadata_json=metadata_json,
    )
    db.add(locked_pool)
    db.add(entry)
    db.flush()
    return PoolMoveResult(pool=locked_pool, ledger_entry=entry)


def mint_to_founder_supply(
    db: Session,
    *,
    actor: User,
    amount: int,
    idempotency_key: str,
    reason: str,
) -> PoolMoveResult:
    if not role_service.is_founder_owner(actor):
        raise HTTPException(status_code=403, detail="Founder Owner permission required")
    pool = get_founder_supply_pool(db)
    return move_pool_balance(
        db,
        pool=pool,
        direction=CoinPoolLedgerDirection.CREDIT,
        source=CoinPoolLedgerSource.FOUNDER_MINT,
        amount=amount,
        idempotency_key=idempotency_key,
        actor_user_id=actor.id,
        reference_type="founder_mint",
        reference_id=idempotency_key,
        reason=reason,
        metadata_json={"note": "Supply pool coins are not user wallet coins"},
    )


def allocate_pool_to_pool(
    db: Session,
    *,
    actor: User,
    from_pool: CoinSupplyPool,
    to_pool: CoinSupplyPool,
    amount: int,
    idempotency_key: str,
    reason: str,
    source: CoinPoolLedgerSource,
) -> tuple[PoolMoveResult, PoolMoveResult]:
    require_founder_or_owner(actor)
    if from_pool.id == to_pool.id:
        raise HTTPException(status_code=400, detail="Cannot transfer to same coin pool")

    debit = move_pool_balance(
        db,
        pool=from_pool,
        direction=CoinPoolLedgerDirection.DEBIT,
        source=source,
        amount=amount,
        idempotency_key=f"{idempotency_key}:debit",
        actor_user_id=actor.id,
        counterparty_user_id=to_pool.owner_user_id,
        related_pool_id=to_pool.id,
        reference_type="pool_transfer",
        reference_id=idempotency_key,
        reason=reason,
    )
    credit = move_pool_balance(
        db,
        pool=to_pool,
        direction=CoinPoolLedgerDirection.CREDIT,
        source=source,
        amount=amount,
        idempotency_key=f"{idempotency_key}:credit",
        actor_user_id=actor.id,
        counterparty_user_id=from_pool.owner_user_id,
        related_pool_id=from_pool.id,
        reference_type="pool_transfer",
        reference_id=idempotency_key,
        reason=reason,
    )
    return debit, credit


def deliver_recharge_from_pool(
    db: Session,
    *,
    actor: User,
    seller_pool: CoinSupplyPool,
    buyer: User,
    coins: int,
    idempotency_key: str,
    reason: str,
) -> PoolMoveResult:
    if seller_pool.owner_user_id != actor.id and not role_service.is_owner_or_above(actor):
        raise HTTPException(status_code=403, detail="You can deliver only from your own coin pool")
    if seller_pool.pool_type not in {CoinPoolType.MERCHANT, CoinPoolType.COIN_SELLER, CoinPoolType.RESELLER}:
        raise HTTPException(status_code=400, detail="Only merchant/seller/reseller pools can deliver user recharges")
    return move_pool_balance(
        db,
        pool=seller_pool,
        direction=CoinPoolLedgerDirection.DEBIT,
        source=CoinPoolLedgerSource.USER_RECHARGE_DELIVERY,
        amount=coins,
        idempotency_key=f"{idempotency_key}:pool_debit",
        actor_user_id=actor.id,
        counterparty_user_id=buyer.id,
        reference_type="user_recharge_delivery",
        reference_id=idempotency_key,
        reason=reason,
        metadata_json={"buyer_user_id": buyer.id},
    )
