from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyCurrency, WalletLedger
from app.models.user import User
from app.services import economy_service

router = APIRouter(prefix="/wallet", tags=["Wallet"])

COINS_PER_INR = 1000
VIP_MAX_LEVEL = 50
SVIP_MAX_LEVEL = 10
VIP_MAX_LIFETIME_RECHARGE_COINS = 40_000_000_000
SVIP_MAX_MONTHLY_RECHARGE_COINS = 200_000_000


class WalletResponse(BaseModel):
    user_id: int
    coin_balance: int
    ruby_balance: int
    withdrawable_rubies: int
    pending_withdraw_rubies: int
    lifetime_coins_spent: int
    lifetime_rubies_earned: int
    lifetime_recharge_coins: int
    monthly_recharge_coins: int
    monthly_recharge_period: str
    vip_level: int
    svip_level: int
    svip_expires_at: str | None = None
    coin_price_text: str = "1 lakh coins = ₹100"
    vip_max_level: int = VIP_MAX_LEVEL
    svip_max_level: int = SVIP_MAX_LEVEL
    vip_max_lifetime_recharge_coins: int = VIP_MAX_LIFETIME_RECHARGE_COINS
    svip_max_monthly_recharge_coins: int = SVIP_MAX_MONTHLY_RECHARGE_COINS
    vip_progress_percent: float
    svip_progress_percent: float


class WalletLedgerEntryResponse(BaseModel):
    id: int
    currency: str
    direction: str
    source: str
    amount: int
    balance_before: int
    balance_after: int
    reason: str | None = None
    created_at: datetime


class WalletRechargeRequest(BaseModel):
    amount_inr: int = Field(gt=0, le=10_000_000)
    provider: str = "mvp"
    provider_reference: str | None = None


class RubyConvertRequest(BaseModel):
    ruby_amount: int = Field(gt=0)


def _month_key() -> str:
    now = datetime.utcnow()
    return f"{now.year:04d}-{now.month:02d}"


def _level_from_progress(value: int, max_value: int, max_level: int) -> int:
    if value <= 0:
        return 0
    if value >= max_value:
        return max_level
    return max(1, min(max_level, int((value / max_value) * max_level)))


def _wallet_response(db: Session, user: User) -> WalletResponse:
    wallet = economy_service.get_or_create_wallet(db, user.id)
    lifetime_recharge = getattr(wallet, "lifetime_recharge_coins", 0) or 0
    monthly_recharge = getattr(wallet, "monthly_recharge_coins", 0) or 0
    vip_level = getattr(wallet, "vip_level", None)
    svip_level = getattr(wallet, "svip_level", None)
    if vip_level is None:
        vip_level = _level_from_progress(lifetime_recharge, VIP_MAX_LIFETIME_RECHARGE_COINS, VIP_MAX_LEVEL)
    if svip_level is None:
        svip_level = _level_from_progress(monthly_recharge, SVIP_MAX_MONTHLY_RECHARGE_COINS, SVIP_MAX_LEVEL)
    return WalletResponse(
        user_id=wallet.user_id,
        coin_balance=wallet.coin_balance,
        ruby_balance=wallet.ruby_balance,
        withdrawable_rubies=max(wallet.ruby_balance - wallet.locked_ruby_balance, 0),
        pending_withdraw_rubies=wallet.pending_withdraw_rubies,
        lifetime_coins_spent=wallet.lifetime_coins_spent,
        lifetime_rubies_earned=wallet.lifetime_rubies_earned,
        lifetime_recharge_coins=lifetime_recharge,
        monthly_recharge_coins=monthly_recharge,
        monthly_recharge_period=getattr(wallet, "monthly_recharge_period", None) or _month_key(),
        vip_level=int(vip_level or 0),
        svip_level=int(svip_level or 0),
        svip_expires_at=str(getattr(wallet, "svip_expires_at", "") or "") or None,
        vip_progress_percent=min(100.0, (lifetime_recharge / VIP_MAX_LIFETIME_RECHARGE_COINS) * 100),
        svip_progress_percent=min(100.0, (monthly_recharge / SVIP_MAX_MONTHLY_RECHARGE_COINS) * 100),
    )


def _credit_recharge(db: Session, user: User, amount_inr: int, provider_reference: str | None) -> None:
    coins = amount_inr * COINS_PER_INR
    wallet = economy_service.get_or_create_wallet(db, user.id)
    before = wallet.coin_balance
    wallet.coin_balance += coins
    if hasattr(wallet, "lifetime_recharge_coins"):
        wallet.lifetime_recharge_coins = (wallet.lifetime_recharge_coins or 0) + coins
    if hasattr(wallet, "monthly_recharge_coins"):
        wallet.monthly_recharge_coins = (wallet.monthly_recharge_coins or 0) + coins
    if hasattr(wallet, "monthly_recharge_period"):
        wallet.monthly_recharge_period = _month_key()
    if hasattr(wallet, "vip_level"):
        wallet.vip_level = _level_from_progress(getattr(wallet, "lifetime_recharge_coins", 0) or 0, VIP_MAX_LIFETIME_RECHARGE_COINS, VIP_MAX_LEVEL)
    if hasattr(wallet, "svip_level"):
        wallet.svip_level = _level_from_progress(getattr(wallet, "monthly_recharge_coins", 0) or 0, SVIP_MAX_MONTHLY_RECHARGE_COINS, SVIP_MAX_LEVEL)
    db.add(WalletLedger(
        user_id=user.id,
        currency_type=EconomyCurrency.COIN.value,
        direction="credit",
        amount=coins,
        before_balance=before,
        after_balance=wallet.coin_balance,
        source_type="RECHARGE",
        source_id=provider_reference,
        created_by_user_id=user.id,
        reason=f"Recharge ₹{amount_inr}",
    ))


@router.get("/me", response_model=WalletResponse)
def get_my_wallet(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    response = _wallet_response(db, current_user)
    db.commit()
    return response


@router.get("/ledger", response_model=list[WalletLedgerEntryResponse])
def get_my_wallet_ledger(limit: int = Query(default=50, ge=1, le=100), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    items = db.query(WalletLedger).filter(WalletLedger.user_id == current_user.id).order_by(WalletLedger.id.desc()).limit(limit).all()
    return [
        WalletLedgerEntryResponse(
            id=item.id,
            currency=item.currency_type,
            direction=item.direction,
            source=item.source_type,
            amount=item.amount,
            balance_before=item.before_balance,
            balance_after=item.after_balance,
            reason=item.reason,
            created_at=item.created_at,
        )
        for item in items
    ]


@router.post("/recharge", response_model=WalletResponse)
def recharge_wallet(payload: WalletRechargeRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _credit_recharge(db, current_user, payload.amount_inr, payload.provider_reference)
    db.commit()
    return _wallet_response(db, current_user)


@router.post("/ruby/convert", response_model=WalletResponse)
def convert_ruby(payload: RubyConvertRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    economy_service.convert_rubies_to_coins(db, current_user, payload.ruby_amount)
    return _wallet_response(db, current_user)
