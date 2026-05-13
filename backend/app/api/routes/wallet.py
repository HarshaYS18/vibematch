from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.wallet import WalletCurrency, WalletLedgerDirection, WalletLedgerEntry, WalletLedgerSource
from app.services.wallet_service import (
    COINS_PER_RUPEE,
    PRICE_PER_LAKH_COINS_INR,
    SVIP_MAX_LEVEL,
    SVIP_MAX_MONTHLY_RECHARGE_COINS,
    VIP_MAX_LEVEL,
    VIP_MAX_LIFETIME_RECHARGE_COINS,
    convert_rubies_to_coins,
    get_or_create_wallet,
    move_wallet_balance,
    recharge_wallet_coins,
)


router = APIRouter(prefix="/wallet", tags=["Wallet"])


class WalletResponse(BaseModel):
    user_id: int
    coin_balance: int
    ruby_balance: int
    lifetime_coin_in: int
    lifetime_coin_out: int
    lifetime_ruby_in: int
    lifetime_ruby_out: int
    lifetime_recharge_coins: int
    monthly_recharge_coins: int
    monthly_recharge_period: str | None
    vip_level: int
    svip_level: int
    svip_expires_at: datetime | None
    coin_price_text: str
    vip_max_level: int
    svip_max_level: int
    vip_max_lifetime_recharge_coins: int
    svip_max_monthly_recharge_coins: int
    vip_progress_percent: float
    svip_progress_percent: float
    is_frozen: bool
    freeze_reason: str | None
    updated_at: datetime


class WalletLedgerEntryResponse(BaseModel):
    id: int
    currency: str
    direction: str
    source: str
    amount: int
    balance_before: int
    balance_after: int
    reference_type: str | None
    reference_id: str | None
    reason: str | None
    metadata_json: dict | None
    created_at: datetime


class WalletGrantRequest(BaseModel):
    amount: int = Field(ge=1, le=10_000_000)
    currency: WalletCurrency = WalletCurrency.COINS
    reason: str = Field(default="MVP test grant", max_length=255)
    idempotency_key: str | None = Field(default=None, max_length=160)


class RechargeRequest(BaseModel):
    amount_inr: int = Field(ge=1, le=10_000_000)
    provider: str = Field(default="mvp", max_length=40)
    provider_reference: str | None = Field(default=None, max_length=120)
    idempotency_key: str | None = Field(default=None, max_length=160)


class RubyConvertRequest(BaseModel):
    ruby_amount: int = Field(ge=1, le=10_000_000)
    idempotency_key: str | None = Field(default=None, max_length=160)


class WithdrawPreviewResponse(BaseModel):
    coins: int
    amount_inr: float
    eligible: bool
    message: str


class RechargePreviewResponse(BaseModel):
    amount_inr: int
    coins: int
    vip_after_level: int
    svip_after_level: int
    coin_price_text: str


def _progress(value: int, max_value: int) -> float:
    if max_value <= 0:
        return 0
    return round(min(100.0, (value / max_value) * 100), 2)


def _wallet_response(user: User, db: Session) -> WalletResponse:
    wallet = get_or_create_wallet(db, user)
    return WalletResponse(
        user_id=user.id,
        coin_balance=wallet.coin_balance,
        ruby_balance=wallet.ruby_balance,
        lifetime_coin_in=wallet.lifetime_coin_in,
        lifetime_coin_out=wallet.lifetime_coin_out,
        lifetime_ruby_in=wallet.lifetime_ruby_in,
        lifetime_ruby_out=wallet.lifetime_ruby_out,
        lifetime_recharge_coins=wallet.lifetime_recharge_coins,
        monthly_recharge_coins=wallet.monthly_recharge_coins,
        monthly_recharge_period=wallet.monthly_recharge_period,
        vip_level=wallet.vip_level,
        svip_level=wallet.svip_level,
        svip_expires_at=wallet.svip_expires_at,
        coin_price_text=f"1 lakh coins = ₹{PRICE_PER_LAKH_COINS_INR}",
        vip_max_level=VIP_MAX_LEVEL,
        svip_max_level=SVIP_MAX_LEVEL,
        vip_max_lifetime_recharge_coins=VIP_MAX_LIFETIME_RECHARGE_COINS,
        svip_max_monthly_recharge_coins=SVIP_MAX_MONTHLY_RECHARGE_COINS,
        vip_progress_percent=_progress(wallet.lifetime_recharge_coins, VIP_MAX_LIFETIME_RECHARGE_COINS),
        svip_progress_percent=_progress(wallet.monthly_recharge_coins, SVIP_MAX_MONTHLY_RECHARGE_COINS),
        is_frozen=wallet.is_frozen,
        freeze_reason=wallet.freeze_reason,
        updated_at=wallet.updated_at,
    )


@router.get("/me", response_model=WalletResponse)
def get_my_wallet(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _wallet_response(current_user, db)


@router.get("/ledger", response_model=list[WalletLedgerEntryResponse])
def get_my_wallet_ledger(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    safe_limit = max(1, min(limit, 100))
    wallet = get_or_create_wallet(db, current_user)
    entries = db.query(WalletLedgerEntry).filter(WalletLedgerEntry.wallet_id == wallet.id).order_by(WalletLedgerEntry.id.desc()).limit(safe_limit).all()
    return [
        WalletLedgerEntryResponse(
            id=entry.id,
            currency=entry.currency.value,
            direction=entry.direction.value,
            source=entry.source.value,
            amount=entry.amount,
            balance_before=entry.balance_before,
            balance_after=entry.balance_after,
            reference_type=entry.reference_type,
            reference_id=entry.reference_id,
            reason=entry.reason,
            metadata_json=entry.metadata_json,
            created_at=entry.created_at,
        )
        for entry in entries
    ]


@router.get("/recharge-preview", response_model=RechargePreviewResponse)
def get_recharge_preview(
    amount_inr: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if amount_inr <= 0:
        raise HTTPException(status_code=400, detail="amount_inr must be greater than zero")
    wallet = get_or_create_wallet(db, current_user)
    coins = amount_inr * COINS_PER_RUPEE
    vip_after = min(VIP_MAX_LEVEL, int(((wallet.lifetime_recharge_coins + coins) * VIP_MAX_LEVEL) // VIP_MAX_LIFETIME_RECHARGE_COINS) or 1)
    svip_after = min(SVIP_MAX_LEVEL, int(((wallet.monthly_recharge_coins + coins) * SVIP_MAX_LEVEL) // SVIP_MAX_MONTHLY_RECHARGE_COINS) or 1)
    return RechargePreviewResponse(
        amount_inr=amount_inr,
        coins=coins,
        vip_after_level=vip_after,
        svip_after_level=svip_after,
        coin_price_text=f"1 lakh coins = ₹{PRICE_PER_LAKH_COINS_INR}",
    )


@router.post("/recharge", response_model=WalletResponse)
def recharge_wallet(
    payload: RechargeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    key = payload.idempotency_key or f"recharge:{current_user.id}:{payload.amount_inr}:{payload.provider}:{payload.provider_reference or 'mvp'}"
    recharge_wallet_coins(
        db,
        user=current_user,
        amount_inr=payload.amount_inr,
        idempotency_key=key,
        provider=payload.provider,
        provider_reference=payload.provider_reference,
    )
    db.commit()
    return _wallet_response(current_user, db)


@router.post("/ruby/convert", response_model=WalletResponse)
def convert_ruby_to_coins(
    payload: RubyConvertRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    key = payload.idempotency_key or f"ruby_convert:{current_user.id}:{payload.ruby_amount}:{datetime.utcnow().timestamp()}"
    convert_rubies_to_coins(db, user=current_user, ruby_amount=payload.ruby_amount, idempotency_key=key)
    db.commit()
    return _wallet_response(current_user, db)


@router.get("/withdraw-preview", response_model=WithdrawPreviewResponse)
def get_withdraw_preview(coins: int):
    if coins <= 0:
        return WithdrawPreviewResponse(coins=coins, amount_inr=0, eligible=False, message="Enter valid coin amount")
    amount = coins / COINS_PER_RUPEE
    eligible = coins >= 10_000
    return WithdrawPreviewResponse(
        coins=coins,
        amount_inr=round(amount, 2),
        eligible=eligible,
        message="Eligible for review" if eligible else "Minimum withdrawal is 10,000 coins",
    )


@router.post("/mvp-grant", response_model=WalletResponse)
def grant_mvp_test_coins(
    payload: WalletGrantRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    key = payload.idempotency_key or f"mvp_grant:{current_user.id}:{payload.currency.value}:{payload.amount}:{payload.reason}"
    move_wallet_balance(
        db,
        user=current_user,
        currency=payload.currency,
        direction=WalletLedgerDirection.CREDIT,
        source=WalletLedgerSource.SYSTEM_GRANT,
        amount=payload.amount,
        idempotency_key=key,
        reference_type="mvp_grant",
        reference_id=str(current_user.id),
        reason=payload.reason,
        metadata_json={"mvp": True},
    )
    db.commit()
    return _wallet_response(current_user, db)
