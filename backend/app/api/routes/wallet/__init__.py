from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.user import User
from app.models.vip_status import UserVipStatus
from app.schemas.economy import RubyWithdrawRequestCreate
from app.services import economy_level_service, economy_service, economy_service_client
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/wallets", tags=["Wallets"])

COINS_PER_RUPEE = 1_000
PRICE_PER_LAKH_COINS_INR = 100
VIP_MAX_LEVEL = 50
SVIP_MAX_LEVEL = 10
VIP_MAX_LIFETIME_RECHARGE_COINS = 50_000_000_000
SVIP_MAX_MONTHLY_RECHARGE_COINS = 2_000_000_000


class WalletResponse(BaseModel):
    user_id: int
    coin_balance: int
    ruby_balance: int
    withdrawable_rubies: int
    pending_withdraw_rubies: int
    lifetime_coins_spent: int
    lifetime_coins_received_as_gifts: int = 0
    lifetime_rubies_earned: int
    lifetime_recharge_coins: int
    monthly_recharge_coins: int
    monthly_recharge_period: str
    monthly_gift_coins_sent: int = 0
    monthly_gift_coins_received: int = 0
    lifetime_send_exp: int = 0
    lifetime_receive_exp: int = 0
    sent_level: int = 0
    receive_level: int = 0
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
    sent: dict = Field(default_factory=dict)
    received: dict = Field(default_factory=dict)
    vip: dict = Field(default_factory=dict)
    svip: dict = Field(default_factory=dict)


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
    request_id: str | None = Field(default=None, min_length=8, max_length=36)


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
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user.id).first()
    levels = economy_level_service.user_level_payload(db, user.id)
    status = db.query(UserVipStatus).filter(UserVipStatus.user_id == user.id).first()
    vip_progress = levels["vip"]
    svip_progress = levels["svip"]
    lifetime_recharge = levels["lifetime_recharge_coin_exp"]
    monthly_recharge = levels["monthly_recharge_coin_exp"]

    def value(field: str) -> int:
        return int(getattr(wallet, field, 0) or 0) if wallet is not None else 0

    vip_level = int(status.vip_level or 0) if status is not None else int(vip_progress.get("level") or 0)
    svip_level = int(status.svip_level or 0) if status is not None else int(svip_progress.get("level") or 0)
    svip_expires_at = status.svip_expires_at if status is not None else None

    return WalletResponse(
        user_id=user.id,
        coin_balance=value("coin_balance"),
        ruby_balance=value("ruby_balance"),
        withdrawable_rubies=max(
            value("ruby_balance") - value("locked_ruby_balance"),
            0,
        ),
        pending_withdraw_rubies=value("pending_withdraw_rubies"),
        lifetime_coins_spent=value("lifetime_coins_spent"),
        lifetime_coins_received_as_gifts=value("lifetime_coins_received_as_gifts"),
        lifetime_rubies_earned=value("lifetime_rubies_earned"),
        lifetime_recharge_coins=lifetime_recharge,
        monthly_recharge_coins=monthly_recharge,
        monthly_recharge_period=_period(),
        monthly_gift_coins_sent=levels["monthly_gift_coins_sent"],
        monthly_gift_coins_received=levels["monthly_gift_coins_received"],
        lifetime_send_exp=levels["lifetime_send_exp"],
        lifetime_receive_exp=levels["lifetime_receive_exp"],
        sent_level=int(levels["sent"].get("level") or 0),
        receive_level=int(levels["received"].get("level") or 0),
        vip_level=vip_level,
        svip_level=svip_level,
        svip_expires_at=svip_expires_at,
        coin_price_text=f"1 lakh coins = Rs {PRICE_PER_LAKH_COINS_INR}",
        vip_max_level=int(vip_progress.get("max_level") or VIP_MAX_LEVEL),
        svip_max_level=int(svip_progress.get("max_level") or SVIP_MAX_LEVEL),
        vip_max_lifetime_recharge_coins=int(
            vip_progress.get("max_total_exp") or VIP_MAX_LIFETIME_RECHARGE_COINS
        ),
        svip_max_monthly_recharge_coins=int(
            svip_progress.get("max_total_exp") or SVIP_MAX_MONTHLY_RECHARGE_COINS
        ),
        vip_progress_percent=round(float(vip_progress.get("progress") or 0) * 100, 2),
        svip_progress_percent=round(float(svip_progress.get("progress") or 0) * 100, 2),
        sent=levels["sent"],
        received=levels["received"],
        vip=vip_progress,
        svip=svip_progress,
    )

def _response_json(response: WalletResponse) -> dict:
    if hasattr(response, "model_dump"):
        return response.model_dump(mode="json")
    return response.dict()


async def _broadcast_wallet_update(user_id: int, response: WalletResponse) -> None:
    wallet_payload = _response_json(response)
    await inbox_ws_manager.send_to_user(
        user_id,
        {
            "event": "wallet_vip_svip_updated",
            "payload": {
                "wallet": wallet_payload,
                "vip": wallet_payload.get("vip"),
                "svip": wallet_payload.get("svip"),
                "coin_balance": wallet_payload.get("coin_balance"),
                "ruby_balance": wallet_payload.get("ruby_balance"),
                "lifetime_recharge_coin_exp": wallet_payload.get("lifetime_recharge_coins"),
                "monthly_recharge_coin_exp": wallet_payload.get("monthly_recharge_coins"),
            },
        },
    )


@router.get("/me", response_model=WalletResponse)
def get_my_wallet(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _wallet_response(db, current_user)


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
def recharge_wallet(
    payload: RechargeRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    provider_reference = (
        payload.provider_reference or f"legacy-{uuid4()}"
    ).strip()
    try:
        economy_service_client.recharge_wallet(
            user_id=current_user.id,
            amount_inr=payload.amount_inr,
            provider_reference=provider_reference,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    db.expire_all()
    response = _wallet_response(db, current_user)
    background_tasks.add_task(_broadcast_wallet_update, current_user.id, response)
    return response


@router.post("/rubies/convert", response_model=WalletResponse)
def convert_ruby_to_coins(
    payload: RubyConvertRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        economy_service_client.convert_ruby(
            user_id=current_user.id,
            ruby_amount=payload.ruby_amount,
            request_id=request_id,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    db.expire_all()
    response = _wallet_response(db, current_user)
    background_tasks.add_task(_broadcast_wallet_update, current_user.id, response)
    return response


@router.post("/rubies/withdraw")
def request_ruby_withdrawal(
    payload: RubyWithdrawRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.withdraw_ruby(
            user_id=current_user.id,
            ruby_amount=payload.ruby_amount,
            payout_method=payload.payout_method,
            payout_account_snapshot=payload.payout_account_snapshot,
            request_id=request_id,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return {
        "id": int(result["request_id"]),
        "ruby_amount": int(result["ruby_amount"]),
        "status": str(result["status"]),
    }
