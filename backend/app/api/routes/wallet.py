from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.wallet import WalletCurrency, WalletLedgerDirection, WalletLedgerEntry, WalletLedgerSource
from app.services.wallet_service import get_or_create_wallet, move_wallet_balance


router = APIRouter(prefix="/wallet", tags=["Wallet"])


class WalletResponse(BaseModel):
    user_id: int
    coin_balance: int
    ruby_balance: int
    lifetime_coin_in: int
    lifetime_coin_out: int
    lifetime_ruby_in: int
    lifetime_ruby_out: int
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
    created_at: datetime


class WalletGrantRequest(BaseModel):
    amount: int = Field(ge=1, le=10_000_000)
    currency: WalletCurrency = WalletCurrency.COINS
    reason: str = Field(default="MVP test grant", max_length=255)
    idempotency_key: str | None = Field(default=None, max_length=160)


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
        is_frozen=wallet.is_frozen,
        freeze_reason=wallet.freeze_reason,
        updated_at=wallet.updated_at,
    )


@router.get("/me", response_model=WalletResponse)
def get_my_wallet(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _wallet_response(current_user, db)


@router.get("/ledger", response_model=list[WalletLedgerEntryResponse])
def get_my_wallet_ledger(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    safe_limit = max(1, min(limit, 100))
    wallet = get_or_create_wallet(db, current_user)
    entries = (
        db.query(WalletLedgerEntry)
        .filter(WalletLedgerEntry.wallet_id == wallet.id)
        .order_by(WalletLedgerEntry.id.desc())
        .limit(safe_limit)
        .all()
    )
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
            created_at=entry.created_at,
        )
        for entry in entries
    ]


@router.post("/mvp-grant", response_model=WalletResponse)
def grant_mvp_test_coins(
    payload: WalletGrantRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Temporary MVP-only route so testing can continue before real recharge is built.
    # Remove or protect behind Founder/Owner permission before production.
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
