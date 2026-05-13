from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinPoolLedgerEntry, CoinPoolLedgerSource, CoinPoolType, CoinSupplyPool
from app.models.role import RoleName
from app.models.user import User
from app.services import role_service
from app.services.economy_pool_service import (
    allocate_pool_to_pool,
    deliver_recharge_from_pool,
    get_founder_supply_pool,
    get_or_create_coin_pool,
    mint_to_founder_supply,
    user_allowed_pool_types,
)
from app.services.wallet_service import COINS_PER_RUPEE, recharge_wallet_coins
from app.websocket.wallet_ws import wallet_ws_manager


router = APIRouter(prefix="/economy", tags=["Economy Coin Pools"])


class CoinPoolResponse(BaseModel):
    id: int
    pool_type: str
    owner_user_id: int | None
    coin_balance: int
    lifetime_coin_in: int
    lifetime_coin_out: int
    is_active: bool
    is_locked: bool
    lock_reason: str | None
    created_at: datetime
    updated_at: datetime


class CoinPoolLedgerResponse(BaseModel):
    id: int
    pool_id: int
    direction: str
    source: str
    amount: int
    balance_before: int
    balance_after: int
    counterparty_user_id: int | None
    related_pool_id: int | None
    reference_type: str | None
    reference_id: str | None
    reason: str | None
    created_at: datetime


class FounderMintRequest(BaseModel):
    amount: int = Field(ge=1, le=100_000_000_000)
    reason: str = Field(min_length=3, max_length=255)
    idempotency_key: str | None = Field(default=None, max_length=180)


class CreatePoolRequest(BaseModel):
    owner_user_id: int
    pool_type: CoinPoolType
    reason: str = Field(default="Create business coin pool", max_length=255)


class PoolTransferRequest(BaseModel):
    from_pool_id: int
    to_pool_id: int
    amount: int = Field(ge=1, le=100_000_000_000)
    reason: str = Field(min_length=3, max_length=255)
    idempotency_key: str | None = Field(default=None, max_length=180)


class PoolRechargeDeliveryRequest(BaseModel):
    pool_id: int
    buyer_user_id: int
    amount_inr: int = Field(ge=1, le=10_000_000)
    reason: str = Field(default="Business coin recharge delivery", max_length=255)
    idempotency_key: str | None = Field(default=None, max_length=180)


def _pool_response(pool: CoinSupplyPool) -> CoinPoolResponse:
    return CoinPoolResponse(
        id=pool.id,
        pool_type=pool.pool_type.value,
        owner_user_id=pool.owner_user_id,
        coin_balance=pool.coin_balance,
        lifetime_coin_in=pool.lifetime_coin_in,
        lifetime_coin_out=pool.lifetime_coin_out,
        is_active=pool.is_active,
        is_locked=pool.is_locked,
        lock_reason=pool.lock_reason,
        created_at=pool.created_at,
        updated_at=pool.updated_at,
    )


def _ledger_response(entry: CoinPoolLedgerEntry) -> CoinPoolLedgerResponse:
    return CoinPoolLedgerResponse(
        id=entry.id,
        pool_id=entry.pool_id,
        direction=entry.direction.value,
        source=entry.source.value,
        amount=entry.amount,
        balance_before=entry.balance_before,
        balance_after=entry.balance_after,
        counterparty_user_id=entry.counterparty_user_id,
        related_pool_id=entry.related_pool_id,
        reference_type=entry.reference_type,
        reference_id=entry.reference_id,
        reason=entry.reason,
        created_at=entry.created_at,
    )


def _get_pool_or_404(db: Session, pool_id: int) -> CoinSupplyPool:
    pool = db.query(CoinSupplyPool).filter(CoinSupplyPool.id == pool_id).first()
    if not pool:
        raise HTTPException(status_code=404, detail="Coin pool not found")
    return pool


def _assert_actor_can_view_pool(actor: User, pool: CoinSupplyPool) -> None:
    if role_service.is_owner_or_above(actor):
        return
    if pool.owner_user_id == actor.id:
        return
    raise HTTPException(status_code=403, detail="You cannot view this coin pool")


@router.get("/coin-pools/me", response_model=list[CoinPoolResponse])
def get_my_coin_pools(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    allowed = user_allowed_pool_types(current_user)
    for pool_type in allowed:
        if pool_type != CoinPoolType.FOUNDER_SUPPLY:
            get_or_create_coin_pool(db, pool_type=pool_type, owner_user_id=current_user.id)
    db.commit()
    pools = db.query(CoinSupplyPool).filter(CoinSupplyPool.owner_user_id == current_user.id).all()
    if role_service.is_founder_owner(current_user):
        founder_pool = get_founder_supply_pool(db)
        pools = [founder_pool, *pools]
    return [_pool_response(pool) for pool in pools]


@router.get("/coin-pools/{pool_id}/ledger", response_model=list[CoinPoolLedgerResponse])
def get_coin_pool_ledger(
    pool_id: int,
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    pool = _get_pool_or_404(db, pool_id)
    _assert_actor_can_view_pool(current_user, pool)
    entries = (
        db.query(CoinPoolLedgerEntry)
        .filter(CoinPoolLedgerEntry.pool_id == pool.id)
        .order_by(CoinPoolLedgerEntry.id.desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    return [_ledger_response(entry) for entry in entries]


@router.post("/coin-pools/founder/mint", response_model=CoinPoolResponse)
def mint_founder_supply(
    payload: FounderMintRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    key = payload.idempotency_key or f"founder_mint:{current_user.id}:{payload.amount}:{payload.reason}"
    result = mint_to_founder_supply(db, actor=current_user, amount=payload.amount, idempotency_key=key, reason=payload.reason)
    db.commit()
    db.refresh(result.pool)
    return _pool_response(result.pool)


@router.post("/coin-pools", response_model=CoinPoolResponse)
def create_business_coin_pool(
    payload: CreatePoolRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not role_service.is_owner_or_above(current_user):
        raise HTTPException(status_code=403, detail="Founder Owner or Owner permission required")
    if payload.pool_type == CoinPoolType.FOUNDER_SUPPLY:
        raise HTTPException(status_code=400, detail="Founder supply pool is platform-owned")
    target = db.query(User).filter(User.id == payload.owner_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Owner user not found")
    target_role = role_service.get_primary_role(target)
    expected_roles: dict[CoinPoolType, set[RoleName]] = {
        CoinPoolType.MERCHANT: {RoleName.MERCHANT},
        CoinPoolType.COIN_SELLER: {RoleName.COIN_SELLER},
        CoinPoolType.RESELLER: {RoleName.RESELLER},
        CoinPoolType.AGENCY: {RoleName.AGENCY_OWNER},
    }
    if target_role not in expected_roles.get(payload.pool_type, set()):
        raise HTTPException(status_code=400, detail="Target user role does not match requested pool type")
    pool = get_or_create_coin_pool(db, pool_type=payload.pool_type, owner_user_id=target.id)
    db.commit()
    db.refresh(pool)
    return _pool_response(pool)


@router.post("/coin-pools/transfer", response_model=list[CoinPoolResponse])
def transfer_between_coin_pools(
    payload: PoolTransferRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from_pool = _get_pool_or_404(db, payload.from_pool_id)
    to_pool = _get_pool_or_404(db, payload.to_pool_id)
    key = payload.idempotency_key or f"pool_transfer:{from_pool.id}:{to_pool.id}:{payload.amount}:{payload.reason}"
    source = CoinPoolLedgerSource.FOUNDER_ALLOCATION if from_pool.pool_type == CoinPoolType.FOUNDER_SUPPLY else CoinPoolLedgerSource.MERCHANT_ALLOCATION
    allocate_pool_to_pool(
        db,
        actor=current_user,
        from_pool=from_pool,
        to_pool=to_pool,
        amount=payload.amount,
        idempotency_key=key,
        reason=payload.reason,
        source=source,
    )
    db.commit()
    db.refresh(from_pool)
    db.refresh(to_pool)
    return [_pool_response(from_pool), _pool_response(to_pool)]


@router.post("/coin-pools/deliver-recharge", response_model=dict)
async def deliver_user_recharge_from_pool(
    payload: PoolRechargeDeliveryRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    pool = _get_pool_or_404(db, payload.pool_id)
    buyer = db.query(User).filter(User.id == payload.buyer_user_id).first()
    if not buyer:
        raise HTTPException(status_code=404, detail="Buyer user not found")
    coins = payload.amount_inr * COINS_PER_RUPEE
    key = payload.idempotency_key or f"pool_recharge:{pool.id}:{buyer.id}:{payload.amount_inr}:{datetime.utcnow().timestamp()}"
    deliver_recharge_from_pool(
        db,
        actor=current_user,
        seller_pool=pool,
        buyer=buyer,
        coins=coins,
        idempotency_key=key,
        reason=payload.reason,
    )
    wallet_result = recharge_wallet_coins(
        db,
        user=buyer,
        amount_inr=payload.amount_inr,
        idempotency_key=f"{key}:wallet_recharge",
        provider=f"pool:{pool.pool_type.value}",
        provider_reference=key,
    )
    db.commit()
    db.refresh(pool)
    db.refresh(wallet_result.wallet)
    await wallet_ws_manager.wallet_updated(
        buyer.id,
        {
            "coin_balance": wallet_result.wallet.coin_balance,
            "ruby_balance": wallet_result.wallet.ruby_balance,
            "vip_level": wallet_result.wallet.vip_level,
            "svip_level": wallet_result.wallet.svip_level,
            "source": "coin_pool_recharge",
        },
    )
    return {
        "pool": _pool_response(pool).model_dump(),
        "buyer_user_id": buyer.id,
        "delivered_coins": coins,
        "buyer_coin_balance": wallet_result.wallet.coin_balance,
        "buyer_vip_level": wallet_result.wallet.vip_level,
        "buyer_svip_level": wallet_result.wallet.svip_level,
    }
