from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.user import User
from app.models.vip_status import UserVipStatus
from app.services import economy_service

router = APIRouter(prefix="/wallet", tags=["Wallet"])

COINS_PER_RUPEE = 1_000
PRICE_PER_LAKH_COINS_INR = 100
VIP_MAX_LEVEL = 50
SVIP_MAX_LEVEL = 10
VIP_MAX_LIFETIME_RECHARGE_COINS = 40_000_000_000
SVIP_MAX_MONTHLY_RECHARGE_COINS = 2_000_000_000


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
    svip_expires_at: datetime | None
    coin_price_text: str
    vip_max_level: int
    svip_max_level: int
    vip_max_lifetime_recharge_coins: int
    svip_max_monthly_recharge_coins: int
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
    reason: str | None
    created_at: datetime


class RechargeRequest(BaseModel):
    amount_inr: int = Field(ge=1, le=10_000_000)
    provider: str = Field(default="mvp", max_length=40)
    provider_reference: str | None = Field(default=None, max_length=120)


class RubyConvertRequest(BaseModel):
    ruby_amount: int = Field(ge=1, le=10_000_000)


def _period() -> str:
    return datetime.utcnow().strftime("%Y-%m")


def _progress(value: int, max_value: int) -> float:
    if max_value <= 0:
        return 0
    return round(min(100.0, (value / max_value) * 100), 2)


def _vip_level(coins: int) -> int:
    if coins <= 0:
        return 0
    return min(VIP_MAX_LEVEL, max(1, int((coins * VIP_MAX_LEVEL) // VIP_MAX_LIFETIME_RECHARGE_COINS)))


def _svip_level(coins: int) -> int:
    if coins <= 0:
        return 0
    return min(SVIP_MAX_LEVEL, max(1, int((coins * SVIP_MAX_LEVEL) // SVIP_MAX_MONTHLY_RECHARGE_COINS)))


def _next_month_start() -> datetime:
    now = datetime.utcnow()
    year = now.year + (1 if now.month == 12 else 0)
    month = 1 if now.month == 12 else now.month + 1
    return datetime(year, month, 1)


def _recharge_totals(db: Session, user_id: int) -> tuple[int, int]:
    rows = (
        db.query(WalletLedger)
        .filter(
            WalletLedger.user_id == user_id,
            WalletLedger.currency_type == EconomyCurrency.COIN.value,
            WalletLedger.direction == EconomyDirection.CREDIT.value,
            WalletLedger.source_type.in_(["RECHARGE", "SELLER_COIN_SALE"]),
        )
        .all()
    )
    period_prefix = _period()
    lifetime = sum(row.amount for row in rows)
    monthly = sum(row.amount for row in rows if row.created_at.strftime("%Y-%m") == period_prefix)
    return lifetime, monthly


def _get_or_update_vip_status(db: Session, user_id: int, lifetime_recharge: int, monthly_recharge: int) -> UserVipStatus:
    status = db.query(UserVipStatus).filter(UserVipStatus.user_id == user_id).first()
    if status is None:
        status = UserVipStatus(user_id=user_id)
        db.add(status)
    status.vip_level = _vip_level(lifetime_recharge)
    status.svip_level = _svip_level(monthly_recharge)
    status.vip_is_active = status.vip_level > 0
    status.svip_is_active = status.svip_level > 0
    status.svip_expires_at = _next_month_start() if status.svip_level > 0 else None
    status.update_reason = "Recharge based VIP/SVIP sync"
    db.add(status)
    db.flush()
    return status


def _wallet_response(db: Session, user: User) -> WalletResponse:
    wallet = economy_service.get_or_create_wallet(db, user.id)
    lifetime_recharge, monthly_recharge = _recharge_totals(db, user.id)
    status = _get_or_update_vip_status(db, user.id, lifetime_recharge, monthly_recharge)
    return WalletResponse(
        user_id=user.id,
        coin_balance=wallet.coin_balance,
        ruby_balance=wallet.ruby_balance,
        withdrawable_rubies=max(wallet.ruby_balance - wallet.locked_ruby_balance, 0),
        pending_withdraw_rubies=wallet.pending_withdraw_rubies,
        lifetime_coins_spent=wallet.lifetime_coins_spent,
        lifetime_rubies_earned=wallet.lifetime_rubies_earned,
        lifetime_recharge_coins=lifetime_recharge,
        monthly_recharge_coins=monthly_recharge,
        monthly_recharge_period=_period(),
        vip_level=status.vip_level,
        svip_level=status.svip_level,
        svip_expires_at=status.svip_expires_at,
        coin_price_text=f"1 lakh coins = ₹{PRICE_PER_LAKH_COINS_INR}",
        vip_max_level=VIP_MAX_LEVEL,
        svip_max_level=SVIP_MAX_LEVEL,
        vip_max_lifetime_recharge_coins=VIP_MAX_LIFETIME_RECHARGE_COINS,
        svip_max_monthly_recharge_coins=SVIP_MAX_MONTHLY_RECHARGE_COINS,
        vip_progress_percent=_progress(lifetime_recharge, VIP_MAX_LIFETIME_RECHARGE_COINS),
        svip_progress_percent=_progress(monthly_recharge, SVIP_MAX_MONTHLY_RECHARGE_COINS),
    )


@router.get("/me", response_model=WalletResponse)
def get_my_wallet(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    response = _wallet_response(db, current_user)
    db.commit()
    return response


@router.get("/ledger", response_model=list[WalletLedgerEntryResponse])
def get_my_wallet_ledger(
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(WalletLedger)
        .filter(WalletLedger.user_id == current_user.id)
        .order_by(WalletLedger.id.desc())
        .limit(limit)
        .all()
    )
    return [
        WalletLedgerEntryResponse(
            id=row.id,
            currency=row.currency_type.lower(),
            direction=row.direction.lower(),
            source=row.source_type.lower(),
            amount=row.amount,
            balance_before=row.before_balance,
            balance_after=row.after_balance,
            reason=row.reason,
            created_at=row.created_at,
        )
        for row in rows
    ]


@router.post("/recharge", response_model=WalletResponse)
def recharge_wallet(payload: RechargeRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    coins = payload.amount_inr * COINS_PER_RUPEE
    wallet = economy_service.get_or_create_wallet(db, current_user.id)
    before = wallet.coin_balance
    wallet.coin_balance += coins
    db.add(wallet)
    db.add(
        WalletLedger(
            user_id=current_user.id,
            currency_type=EconomyCurrency.COIN.value,
            direction=EconomyDirection.CREDIT.value,
            amount=coins,
            before_balance=before,
            after_balance=wallet.coin_balance,
            source_type="RECHARGE",
            source_id=payload.provider_reference,
            created_by_user_id=current_user.id,
            reason=f"Recharge ₹{payload.amount_inr}",
        )
    )
    db.flush()
    response = _wallet_response(db, current_user)
    db.commit()
    return response


@router.post("/ruby/convert", response_model=WalletResponse)
def convert_ruby_to_coins(payload: RubyConvertRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    economy_service.convert_rubies_to_coins(db, current_user, payload.ruby_amount)
    return _wallet_response(db, current_user)
