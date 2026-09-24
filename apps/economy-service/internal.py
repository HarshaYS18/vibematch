from __future__ import annotations

import json
import hmac
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.economy import (
    EconomyCurrency,
    EconomyPoolStatus,
    GamePool,
    GamePoolType,
    GiftTransaction,
    RubyWithdrawRequest,
    WalletLedger,
)
from app.models.economy_stats import LuckyGiftTransaction
from app.models.user import User
from app.services import (
    economy_bulk_grant_service,
    economy_level_service,
    economy_level_service,
    economy_service,
    economy_transaction_service,
    event_outbox_service,
    house_pool_service,
    lucky_gift_house_service,
    lucky_gift_props_service,
    lucky_gift_stats_service,
    whale_risk_service,
)


router = APIRouter(prefix="/internal/economy", tags=["Economy Internal"])


class MutationContext(BaseModel):
    transaction_id: str = Field(min_length=8, max_length=36)
    idempotency_key: str = Field(min_length=8, max_length=160)
    business_reference: str = Field(min_length=1, max_length=200)


class WalletMutationRequest(MutationContext):
    user_id: int
    amount: int = Field(gt=0)
    currency: str = EconomyCurrency.COIN.value
    source_type: str = Field(min_length=1, max_length=80)
    source_id: str | None = Field(default=None, max_length=120)
    reason: str | None = Field(default=None, max_length=255)
    actor_user_id: int | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class SupplyMintRequest(MutationContext):
    actor_user_id: int
    target_pool_type: str
    target_user_id: int | None = None
    amount: int = Field(gt=0)
    reason: str = Field(min_length=3, max_length=255)


class SupplyAllocateRequest(MutationContext):
    actor_user_id: int
    source_pool_id: int
    target_pool_type: str
    target_user_id: int | None = None
    amount: int = Field(gt=0)
    reason: str = Field(min_length=3, max_length=255)


class SellerSaleCommandRequest(MutationContext):
    seller_user_id: int
    buyer_user_id: int
    source_pool_id: int
    coin_amount: int = Field(gt=0)
    payment_amount: int = Field(default=0, ge=0)
    payment_currency: str = "INR"
    proof_url: str | None = None


class OfficialRechargeCommandRequest(MutationContext):
    actor_user_id: int
    target_user_id: int | None = None
    target_public_user_id: int | None = None
    coin_amount: int = Field(gt=0)
    payment_amount: int = Field(default=0, ge=0)
    payment_currency: str = "INR"
    reason: str = Field(min_length=3, max_length=255)
    proof_url: str | None = None


class GamePoolConfigureCommandRequest(MutationContext):
    actor_user_id: int
    game_key: str = Field(min_length=2, max_length=80)
    pool_type: str
    opening_balance: int = Field(default=0, ge=0)
    daily_payout_cap: int = Field(default=0, ge=0)
    daily_loss_limit: int = Field(default=0, ge=0)
    max_single_payout: int = Field(default=0, ge=0)
    rtp_target_basis_points: int = Field(default=8000, ge=0, le=10000)


class LuckyGiftControlHousePoolCommandRequest(MutationContext):
    actor_user_id: int
    balance: int | None = Field(default=None, ge=0)
    reserved_balance: int | None = Field(default=None, ge=0)
    max_payout_per_round: int | None = Field(default=None, ge=0)
    daily_house_loss_limit: int | None = Field(default=None, ge=0)
    rtp_target_basis_points: int | None = Field(default=None, ge=0, le=10000)
    status: str | None = Field(default=None, max_length=20)
    reason: str = Field(min_length=3, max_length=255)


class LuckyGiftPropsAdminCommandRequest(MutationContext):
    actor_user_id: int
    props: dict[str, Any] = Field(default_factory=dict)


class LuckyGiftPoolAdjustCommandRequest(MutationContext):
    actor_user_id: int
    game_key: str = Field(default="lucky_gifts", min_length=2, max_length=80)
    pool_type: str = Field(default="GAME_HOUSE_POOL", min_length=3, max_length=80)
    direction: str = Field(pattern="^(CREDIT|DEBIT)$")
    amount: int = Field(gt=0)
    reason: str = Field(min_length=3, max_length=255)


class LuckyGiftPoolTransferCommandRequest(MutationContext):
    actor_user_id: int
    amount: int = Field(gt=0)
    reason: str = Field(min_length=3, max_length=255)


class LuckyGiftPoolSettingsCommandRequest(MutationContext):
    actor_user_id: int
    game_key: str = Field(default="lucky_gifts", min_length=2, max_length=80)
    pool_type: str = Field(default="GAME_HOUSE_POOL", min_length=3, max_length=80)
    status: str | None = Field(default=None, pattern="^(ACTIVE|FROZEN|CLOSED)$")
    daily_payout_cap: int | None = Field(default=None, ge=0)
    daily_loss_limit: int | None = Field(default=None, ge=0)
    max_single_payout: int | None = Field(default=None, ge=0)
    rtp_target_basis_points: int | None = Field(default=None, ge=0, le=10000)
    reason: str = Field(min_length=3, max_length=255)


class BulkGrantEnqueueRequest(MutationContext):
    actor_user_id: int
    coin_amount: int = Field(gt=0, le=10_000_000)
    active_only: bool = True
    reason: str = Field(min_length=3, max_length=255)


class MissionRewardRequest(MutationContext):
    user_id: int
    mission_id: str = Field(min_length=1, max_length=120)
    cycle_key: str = Field(min_length=1, max_length=120)
    reward_coin_amount: int = Field(gt=0)


class WalletRechargeRequest(MutationContext):
    user_id: int
    amount_inr: int = Field(gt=0, le=10_000_000)
    provider_reference: str = Field(min_length=1, max_length=120)


class WalletConvertRequest(MutationContext):
    user_id: int
    ruby_amount: int = Field(gt=0, le=10_000_000)


class WalletWithdrawRequest(MutationContext):
    user_id: int
    ruby_amount: int = Field(gt=0)
    payout_method: str | None = None
    payout_account_snapshot: str | None = None


class GiftFinancialRequest(MutationContext):
    sender_user_id: int
    receiver_user_id: int
    gift_id: str = Field(min_length=1, max_length=80)
    gift_name: str | None = Field(default=None, max_length=140)
    coin_value: int = Field(gt=0)
    quantity: int = Field(gt=0)
    room_id: int | None = None
    relationship_id: int | None = None
    is_relationship_gift: bool = False


class GameFinancialRequest(MutationContext):
    user_id: int
    game_id: str = Field(min_length=1, max_length=80)
    round_id: str | None = Field(default=None, max_length=120)
    wager_amount: int = Field(default=0, ge=0)
    win_amount: int = Field(default=0, ge=0)
    multiplier: int = Field(default=0, ge=0)
    metadata: dict[str, Any] = Field(default_factory=dict)


def require_internal_token(
    x_funkey_internal_token: str | None = Header(default=None),
) -> None:
    expected = settings.ECONOMY_INTERNAL_TOKEN.strip()
    provided = (x_funkey_internal_token or "").strip()
    if not expected or not hmac.compare_digest(provided, expected):
        raise HTTPException(status_code=403, detail="Internal Economy access denied")


def _begin(
    db: Session,
    payload: BaseModel,
    *,
    operation: str,
    actor_user_id: int | None,
):
    data = payload.model_dump(mode="json")
    return economy_transaction_service.begin(
        db,
        transaction_id=data["transaction_id"],
        idempotency_key=data["idempotency_key"],
        business_reference=data["business_reference"],
        operation_type=operation,
        actor_user_id=actor_user_id,
        request_payload=data,
    )


def _lucky_gift_metadata(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
    except Exception:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _lucky_gift_transaction_payload(row: LuckyGiftTransaction) -> dict[str, Any]:
    return {
        "transaction_id": row.id,
        "sender_user_id": row.sender_user_id,
        "receiver_user_id": row.receiver_user_id,
        "room_id": row.room_id,
        "gift_id": row.gift_id,
        "gift_name": row.gift_name,
        "spent_coins": int(row.spent_coins or 0),
        "multiplier": int(row.multiplier or 0),
        "reward_coins": int(row.reward_coins or 0),
        "net_win_coins": int(row.net_win_coins or 0),
        "is_big_win": int(row.is_big_win or 0),
        "metadata": _lucky_gift_metadata(row.metadata_json),
        "created_at": row.created_at,
    }



LUCKY_GIFT_CONTROL_POOL_KEY = "lucky_gifts"
LUCKY_GIFT_CONTROL_POOL_TYPE = GamePoolType.GAME_HOUSE_POOL.value


def _get_or_create_lucky_gift_control_pool(db: Session) -> GamePool:
    pool = (
        db.query(GamePool)
        .filter(
            GamePool.game_key == LUCKY_GIFT_CONTROL_POOL_KEY,
            GamePool.pool_type == LUCKY_GIFT_CONTROL_POOL_TYPE,
        )
        .first()
    )
    if pool is not None:
        return pool
    pool = GamePool(
        game_key=LUCKY_GIFT_CONTROL_POOL_KEY,
        pool_type=LUCKY_GIFT_CONTROL_POOL_TYPE,
        balance=0,
        reserved_balance=0,
        status=EconomyPoolStatus.ACTIVE.value,
        daily_payout_cap=0,
        daily_loss_limit=0,
        max_single_payout=0,
        rtp_target_basis_points=8000,
    )
    db.add(pool)
    db.flush()
    return pool


def _lucky_gift_control_pool_payload(db: Session, pool: GamePool) -> dict[str, Any]:
    snapshot = house_pool_service.calculate_payout_pressure(
        db,
        LUCKY_GIFT_CONTROL_POOL_TYPE,
    )
    balance = int(pool.balance or 0)
    reserved = int(pool.reserved_balance or 0)
    pressure = 0.0 if balance <= 0 else min(reserved / max(balance, 1), 1.0)
    risk_tier = "high" if pressure >= 0.75 else "medium" if pressure >= 0.35 else "low"
    return {
        "game_key": pool.game_key,
        "pool_type": pool.pool_type,
        "house_pool_balance": balance,
        "house_reserved_liability": reserved,
        "house_exposure": reserved,
        "max_payout_per_round": int(
            pool.max_single_payout or snapshot.max_payout_per_round or 0
        ),
        "daily_house_loss_limit": int(
            pool.daily_loss_limit or snapshot.daily_house_loss_limit or 0
        ),
        "risk_tier": risk_tier,
        "payout_pressure": pressure,
        "rtp_target_basis_points": int(pool.rtp_target_basis_points or 8000),
        "status": pool.status,
    }



@router.get("/wallet/snapshot/{user_id}", dependencies=[Depends(require_internal_token)])
def wallet_snapshot(user_id: int, db: Session = Depends(get_db)):
    wallet = economy_transaction_service.wallet_for_update(db, user_id)
    db.commit()
    return {
        "user_id": int(user_id),
        "coin_balance": int(wallet.coin_balance or 0),
        "ruby_balance": int(wallet.ruby_balance or 0),
        "pending_withdraw_rubies": int(wallet.pending_withdraw_rubies or 0),
    }


@router.post("/wallet/recharge", dependencies=[Depends(require_internal_token)])
def recharge_wallet(
    payload: WalletRechargeRequest,
    db: Session = Depends(get_db),
):
    tx, cached = _begin(
        db,
        payload,
        operation="wallet.recharge",
        actor_user_id=payload.user_id,
    )
    if cached is not None:
        return cached

    coin_amount = int(payload.amount_inr) * 1000
    wallet = economy_transaction_service.credit(
        db,
        user_id=payload.user_id,
        amount=coin_amount,
        currency=EconomyCurrency.COIN.value,
        source_type="RECHARGE",
        source_id=payload.provider_reference,
        reason=f"Recharge Rs {payload.amount_inr}",
        tx=tx,
        actor_user_id=payload.user_id,
    )
    levels = economy_level_service.wallet_level_payload(db, wallet)
    economy_level_service.sync_vip_status(db, payload.user_id, levels)
    result = {
        "transaction_id": tx.transaction_id,
        "user_id": payload.user_id,
        "coin_balance": int(wallet.coin_balance or 0),
        "ruby_balance": int(wallet.ruby_balance or 0),
        "coin_amount": coin_amount,
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.wallet.recharged.v1",
        event_payload={
            "user_id": payload.user_id,
            "coin_amount": coin_amount,
            "provider_reference": payload.provider_reference,
        },
    )


@router.post("/wallet/convert-ruby", dependencies=[Depends(require_internal_token)])
def convert_ruby(
    payload: WalletConvertRequest,
    db: Session = Depends(get_db),
):
    tx, cached = _begin(
        db,
        payload,
        operation="wallet.convert_ruby",
        actor_user_id=payload.user_id,
    )
    if cached is not None:
        return cached

    wallet = economy_transaction_service.debit(
        db,
        user_id=payload.user_id,
        amount=payload.ruby_amount,
        currency=EconomyCurrency.RUBY.value,
        source_type="RUBY_TO_COIN_CONVERSION",
        source_id=tx.transaction_id,
        reason="Ruby to coin conversion",
        tx=tx,
        actor_user_id=payload.user_id,
    )
    wallet = economy_transaction_service.credit(
        db,
        user_id=payload.user_id,
        amount=payload.ruby_amount,
        currency=EconomyCurrency.COIN.value,
        source_type="RUBY_TO_COIN_CONVERSION",
        source_id=tx.transaction_id,
        reason="Ruby to coin conversion",
        tx=tx,
        actor_user_id=payload.user_id,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "user_id": payload.user_id,
        "coin_balance": int(wallet.coin_balance or 0),
        "ruby_balance": int(wallet.ruby_balance or 0),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.wallet.ruby_converted.v1",
        event_payload={
            "user_id": payload.user_id,
            "ruby_amount": payload.ruby_amount,
        },
    )


@router.post("/wallet/withdraw-ruby", dependencies=[Depends(require_internal_token)])
def withdraw_ruby(
    payload: WalletWithdrawRequest,
    db: Session = Depends(get_db),
):
    tx, cached = _begin(
        db,
        payload,
        operation="wallet.withdraw_ruby",
        actor_user_id=payload.user_id,
    )
    if cached is not None:
        return cached

    wallet = economy_transaction_service.debit(
        db,
        user_id=payload.user_id,
        amount=payload.ruby_amount,
        currency=EconomyCurrency.RUBY.value,
        source_type="RUBY_WITHDRAW_REQUEST",
        source_id=tx.transaction_id,
        reason="Rubies locked for withdrawal review",
        tx=tx,
        actor_user_id=payload.user_id,
    )
    wallet.pending_withdraw_rubies += int(payload.ruby_amount)
    request = RubyWithdrawRequest(
        user_id=payload.user_id,
        ruby_amount=payload.ruby_amount,
        payout_method=payload.payout_method,
        payout_account_snapshot=payload.payout_account_snapshot,
    )
    db.add(request)
    db.flush()

    result = {
        "transaction_id": tx.transaction_id,
        "request_id": request.id,
        "user_id": payload.user_id,
        "ruby_amount": payload.ruby_amount,
        "status": request.status,
        "ruby_balance": int(wallet.ruby_balance or 0),
        "pending_withdraw_rubies": int(wallet.pending_withdraw_rubies or 0),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.wallet.withdrawal_requested.v1",
        event_payload={
            "user_id": payload.user_id,
            "withdraw_request_id": request.id,
            "ruby_amount": payload.ruby_amount,
        },
    )

@router.post("/wallet/debit", dependencies=[Depends(require_internal_token)])
def debit_wallet(payload: WalletMutationRequest, db: Session = Depends(get_db)):
    tx, cached = _begin(
        db,
        payload,
        operation="wallet.debit",
        actor_user_id=payload.actor_user_id,
    )
    if cached is not None:
        return cached
    wallet = economy_transaction_service.debit(
        db,
        user_id=payload.user_id,
        amount=payload.amount,
        currency=payload.currency,
        source_type=payload.source_type,
        source_id=payload.source_id,
        reason=payload.reason,
        tx=tx,
        actor_user_id=payload.actor_user_id,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "user_id": payload.user_id,
        "coin_balance": int(wallet.coin_balance or 0),
        "ruby_balance": int(wallet.ruby_balance or 0),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.wallet.changed.v1",
        event_payload={
            "user_id": payload.user_id,
            "operation": "debit",
            "source_type": payload.source_type,
            "amount": payload.amount,
            "currency": payload.currency,
        },
    )


@router.post("/wallet/credit", dependencies=[Depends(require_internal_token)])
def credit_wallet(payload: WalletMutationRequest, db: Session = Depends(get_db)):
    tx, cached = _begin(
        db,
        payload,
        operation="wallet.credit",
        actor_user_id=payload.actor_user_id,
    )
    if cached is not None:
        return cached
    wallet = economy_transaction_service.credit(
        db,
        user_id=payload.user_id,
        amount=payload.amount,
        currency=payload.currency,
        source_type=payload.source_type,
        source_id=payload.source_id,
        reason=payload.reason,
        tx=tx,
        actor_user_id=payload.actor_user_id,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "user_id": payload.user_id,
        "coin_balance": int(wallet.coin_balance or 0),
        "ruby_balance": int(wallet.ruby_balance or 0),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.wallet.changed.v1",
        event_payload={
            "user_id": payload.user_id,
            "operation": "credit",
            "source_type": payload.source_type,
            "amount": payload.amount,
            "currency": payload.currency,
        },
    )




@router.post("/gifts/settle", dependencies=[Depends(require_internal_token)])
def settle_regular_gift(
    payload: GiftFinancialRequest,
    db: Session = Depends(get_db),
):
    sender = db.query(User).filter(User.id == payload.sender_user_id).first()
    receiver = db.query(User).filter(User.id == payload.receiver_user_id).first()
    if sender is None:
        raise HTTPException(status_code=404, detail="Gift sender not found")
    if receiver is None:
        raise HTTPException(status_code=404, detail="Gift receiver not found")

    tx, cached = _begin(
        db,
        payload,
        operation="gift.settle",
        actor_user_id=payload.sender_user_id,
    )
    if cached is not None:
        return cached

    total_coin_value = int(payload.coin_value) * int(payload.quantity)
    receiver_ruby_amount = total_coin_value * 3000 // 10000
    platform_share_coin_value = total_coin_value - receiver_ruby_amount
    room_exp_amount = total_coin_value if payload.room_id is not None else 0
    love_score_amount = (
        total_coin_value
        if payload.relationship_id is not None or payload.is_relationship_gift
        else 0
    )

    gift_tx = GiftTransaction(
        sender_user_id=payload.sender_user_id,
        receiver_user_id=payload.receiver_user_id,
        room_id=payload.room_id,
        gift_id=payload.gift_id,
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        total_coin_value=total_coin_value,
        receiver_ruby_amount=receiver_ruby_amount,
        platform_share_coin_value=platform_share_coin_value,
        agency_share_coin_value=0,
        room_exp_amount=room_exp_amount,
        send_exp_amount=total_coin_value,
        receive_exp_amount=total_coin_value,
        relationship_id=payload.relationship_id,
        love_score_amount=love_score_amount,
    )
    db.add(gift_tx)
    db.flush()

    sender_wallet = economy_transaction_service.debit(
        db,
        user_id=payload.sender_user_id,
        amount=total_coin_value,
        currency=EconomyCurrency.COIN.value,
        source_type="GIFT_SEND",
        source_id=str(gift_tx.id),
        reason=f"Sent gift {payload.gift_id}",
        tx=tx,
        actor_user_id=payload.sender_user_id,
    )
    receiver_wallet = economy_transaction_service.credit(
        db,
        user_id=payload.receiver_user_id,
        amount=receiver_ruby_amount,
        currency=EconomyCurrency.RUBY.value,
        source_type="GIFT_RECEIVE_RUBY",
        source_id=str(gift_tx.id),
        reason=f"Received gift {payload.gift_id}",
        tx=tx,
        actor_user_id=payload.sender_user_id,
    )
    receiver_wallet.lifetime_coins_received_as_gifts += total_coin_value

    result = {
        "transaction_id": tx.transaction_id,
        "gift_transaction_id": gift_tx.id,
        "sender_user_id": payload.sender_user_id,
        "receiver_user_id": payload.receiver_user_id,
        "total_coin_value": total_coin_value,
        "receiver_ruby_amount": receiver_ruby_amount,
        "platform_share_coin_value": platform_share_coin_value,
        "send_exp_amount": total_coin_value,
        "receive_exp_amount": total_coin_value,
        "room_exp_amount": room_exp_amount,
        "love_score_amount": love_score_amount,
        "sender_coin_balance": int(sender_wallet.coin_balance or 0),
        "receiver_ruby_balance": int(receiver_wallet.ruby_balance or 0),
        "receiver_lifetime_gift_coin_value": int(
            receiver_wallet.lifetime_coins_received_as_gifts or 0
        ),
        "receiver_lifetime_rubies_earned": int(
            receiver_wallet.lifetime_rubies_earned or 0
        ),
        "experience_updates": {},
        "ruby_rule": "Receiver rubies = total gift coin value × 30%.",
        "rule": "Gift financial settlement committed.",
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.gift_settled.v1",
        event_payload={
            "gift_transaction_id": gift_tx.id,
            "sender_user_id": payload.sender_user_id,
            "receiver_user_id": payload.receiver_user_id,
            "room_id": payload.room_id,
            "gift_id": payload.gift_id,
            "quantity": payload.quantity,
            "total_coin_value": total_coin_value,
            "receiver_ruby_amount": receiver_ruby_amount,
        },
    )



@router.post("/gifts/lucky/settle", dependencies=[Depends(require_internal_token)])
def settle_lucky_gift(
    payload: GiftFinancialRequest,
    db: Session = Depends(get_db),
):
    sender = db.query(User).filter(User.id == payload.sender_user_id).first()
    receiver = db.query(User).filter(User.id == payload.receiver_user_id).first()
    if sender is None:
        raise HTTPException(status_code=404, detail="Gift sender not found")
    if receiver is None:
        raise HTTPException(status_code=404, detail="Gift receiver not found")

    tx, cached = _begin(
        db,
        payload,
        operation="gift.lucky.settle",
        actor_user_id=payload.sender_user_id,
    )
    if cached is not None:
        return cached

    total_coin_value = int(payload.coin_value) * int(payload.quantity)
    receiver_ruby_amount = total_coin_value * 3000 // 10000
    platform_share_coin_value = total_coin_value - receiver_ruby_amount
    room_exp_amount = total_coin_value if payload.room_id is not None else 0
    love_score_amount = (
        total_coin_value
        if payload.relationship_id is not None or payload.is_relationship_gift
        else 0
    )
    gift_name = payload.gift_name or payload.gift_id.replace("_", " ").title()

    gift_tx = GiftTransaction(
        sender_user_id=payload.sender_user_id,
        receiver_user_id=payload.receiver_user_id,
        room_id=payload.room_id,
        gift_id=payload.gift_id,
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        total_coin_value=total_coin_value,
        receiver_ruby_amount=receiver_ruby_amount,
        platform_share_coin_value=platform_share_coin_value,
        agency_share_coin_value=0,
        room_exp_amount=room_exp_amount,
        send_exp_amount=total_coin_value,
        receive_exp_amount=total_coin_value,
        relationship_id=payload.relationship_id,
        love_score_amount=love_score_amount,
    )
    db.add(gift_tx)
    db.flush()

    sender_wallet = economy_transaction_service.debit(
        db,
        user_id=payload.sender_user_id,
        amount=total_coin_value,
        currency=EconomyCurrency.COIN.value,
        source_type="GIFT_SEND",
        source_id=str(gift_tx.id),
        reason=f"Sent lucky gift {payload.gift_id}",
        tx=tx,
        actor_user_id=payload.sender_user_id,
    )
    receiver_wallet = economy_transaction_service.credit(
        db,
        user_id=payload.receiver_user_id,
        amount=receiver_ruby_amount,
        currency=EconomyCurrency.RUBY.value,
        source_type="GIFT_RECEIVE_RUBY",
        source_id=str(gift_tx.id),
        reason=f"Received lucky gift {payload.gift_id}",
        tx=tx,
        actor_user_id=payload.sender_user_id,
    )
    receiver_wallet.lifetime_coins_received_as_gifts += total_coin_value

    risk_result = lucky_gift_props_service.evaluate_whale_risk(
        db,
        user_id=payload.sender_user_id,
        spend_amount=total_coin_value,
    )
    spend_income = lucky_gift_house_service.record_spend_income(
        db,
        amount=total_coin_value,
        actor=sender,
        source_id=f"lucky_gift:{gift_tx.id}",
        user_id=payload.sender_user_id,
        metadata={
            "gift_id": payload.gift_id,
            "receiver_user_id": payload.receiver_user_id,
        },
    )
    if int(spend_income.get("amount") or 0) > 0:
        economy_transaction_service.record_balanced_transfer(
            db,
            tx=tx,
            currency=EconomyCurrency.COIN.value,
            amount=int(spend_income["amount"]),
            debit_account="SYSTEM_CLEARING:LUCKY_GIFT_SPEND_INCOME:COIN",
            credit_account="GAME_POOL:" + str(spend_income["pool_id"]) + ":COIN",
            source_type="LUCKY_GIFT_SPEND_INCOME",
        )
    capacity = lucky_gift_house_service.safe_payout_capacity(db)
    lucky_result = lucky_gift_props_service.roll_lucky_gift(
        db,
        gift_id=payload.gift_id,
        gift_name=gift_name,
        base_coin_value=payload.coin_value,
        quantity=payload.quantity,
        house_risk_score=int(risk_result.get("score") or 0),
        max_reward_coin_amount=int(capacity.get("max_safe_payout") or 0),
    )
    reward = int(lucky_result.get("reward_coin_amount") or 0)
    multiplier = int(lucky_result.get("multiplier") or 0)
    house_result = lucky_gift_house_service.validate_payout_exposure(
        db,
        payout_amount=reward,
    )
    payout_movements = lucky_gift_house_service.record_payout(
        db,
        amount=reward,
        actor=sender,
        source_id=f"lucky_gift:{gift_tx.id}",
        user_id=payload.sender_user_id,
        metadata={
            "gift_id": payload.gift_id,
            "multiplier": multiplier,
            "tier": lucky_result.get("tier"),
        },
    )
    for movement in payout_movements.get("movements", []):
        economy_transaction_service.record_balanced_transfer(
            db,
            tx=tx,
            currency=EconomyCurrency.COIN.value,
            amount=int(movement["amount"]),
            debit_account="GAME_POOL:" + str(movement["pool_id"]) + ":COIN",
            credit_account="SYSTEM_CLEARING:LUCKY_GIFT_PAYOUT:COIN",
            source_type=str(movement["source_type"]),
        )
    if reward > 0:
        sender_wallet = economy_transaction_service.credit(
            db,
            user_id=payload.sender_user_id,
            amount=reward,
            currency=EconomyCurrency.COIN.value,
            source_type="LUCKY_GIFT_REWARD",
            source_id=f"lucky_gift:{gift_tx.id}",
            reason="Lucky gift multiplier reward",
            tx=tx,
            actor_user_id=payload.sender_user_id,
        )

    lucky_tx, stats = lucky_gift_stats_service.record_lucky_gift_result(
        db,
        sender_user_id=payload.sender_user_id,
        receiver_user_id=payload.receiver_user_id,
        room_id=payload.room_id,
        gift_id=payload.gift_id,
        gift_name=gift_name,
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        spent_coins=total_coin_value,
        multiplier=multiplier,
        reward_coins=reward,
        net_win_coins=reward - total_coin_value,
        metadata_json=json.dumps(
            {
                "gift_transaction_id": gift_tx.id,
                "source": "economy_service_lucky_gift",
                "lucky_result": lucky_result,
                "risk": risk_result,
                "house": house_result,
                "capacity": capacity,
            },
            separators=(",", ":"),
            default=str,
        ),
    )

    result = {
        "transaction_id": tx.transaction_id,
        "gift_transaction_id": gift_tx.id,
        "lucky_gift_transaction_id": lucky_tx.id,
        "sender_user_id": payload.sender_user_id,
        "receiver_user_id": payload.receiver_user_id,
        "total_coin_value": total_coin_value,
        "receiver_ruby_amount": receiver_ruby_amount,
        "platform_share_coin_value": platform_share_coin_value,
        "send_exp_amount": total_coin_value,
        "receive_exp_amount": total_coin_value,
        "room_exp_amount": room_exp_amount,
        "love_score_amount": love_score_amount,
        "sender_coin_balance": int(sender_wallet.coin_balance or 0),
        "wallet_coin_balance": int(sender_wallet.coin_balance or 0),
        "winner_coin_balance": int(sender_wallet.coin_balance or 0),
        "receiver_ruby_balance": int(receiver_wallet.ruby_balance or 0),
        "receiver_lifetime_gift_coin_value": int(
            receiver_wallet.lifetime_coins_received_as_gifts or 0
        ),
        "receiver_lifetime_rubies_earned": int(
            receiver_wallet.lifetime_rubies_earned or 0
        ),
        "experience_updates": {},
        "ruby_rule": "Receiver rubies = total gift coin value × 30%.",
        "lucky_multiplier": multiplier,
        "lucky_reward_coin_amount": reward,
        "lucky_result": lucky_result,
        "lucky_difficulty": lucky_result.get("difficulty"),
        "risk_level": risk_result.get("level"),
        "risk_score": risk_result.get("score"),
        "risk_action": risk_result.get("action"),
        "spent_coins": total_coin_value,
        "reward_coins": reward,
        "net_win_coins": reward - total_coin_value,
        "rule": f"Lucky gift result: {multiplier}x, reward {reward} coins.",
        "stats": lucky_gift_stats_service.stats_payload(stats),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_gift_settled.v1",
        event_payload={
            "gift_transaction_id": gift_tx.id,
            "lucky_gift_transaction_id": lucky_tx.id,
            "sender_user_id": payload.sender_user_id,
            "receiver_user_id": payload.receiver_user_id,
            "room_id": payload.room_id,
            "gift_id": payload.gift_id,
            "quantity": payload.quantity,
            "total_coin_value": total_coin_value,
            "reward_coin_amount": reward,
            "multiplier": multiplier,
        },
    )

@router.get("/lucky-gifts/admin/control-center/house-pool", dependencies=[Depends(require_internal_token)])
def get_lucky_gift_control_house_pool(db: Session = Depends(get_db)):
    pool = _get_or_create_lucky_gift_control_pool(db)
    db.commit()
    db.refresh(pool)
    return _lucky_gift_control_pool_payload(db, pool)


@router.post("/lucky-gifts/admin/control-center/house-pool", dependencies=[Depends(require_internal_token)])
def update_lucky_gift_control_house_pool(
    payload: LuckyGiftControlHousePoolCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="lucky_gift.control_house_pool.update",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached

    pool = _get_or_create_lucky_gift_control_pool(db)
    before_balance = int(pool.balance or 0)
    if payload.balance is not None:
        pool.balance = int(payload.balance)
    if (
        payload.reserved_balance is not None
        and int(payload.reserved_balance) != int(pool.reserved_balance or 0)
    ):
        raise HTTPException(
            status_code=409,
            detail="reserved_balance is derived from durable Economy reservations",
        )
    if payload.max_payout_per_round is not None:
        pool.max_single_payout = int(payload.max_payout_per_round)
    if payload.daily_house_loss_limit is not None:
        pool.daily_loss_limit = int(payload.daily_house_loss_limit)
        pool.daily_payout_cap = int(payload.daily_house_loss_limit)
    if payload.rtp_target_basis_points is not None:
        pool.rtp_target_basis_points = int(payload.rtp_target_basis_points)
    if payload.status is not None:
        normalized_status = payload.status.upper()
        if normalized_status not in {item.value for item in EconomyPoolStatus}:
            raise HTTPException(status_code=400, detail="Invalid pool status")
        pool.status = normalized_status
    db.flush()

    balance_delta = int(pool.balance or 0) - before_balance
    if balance_delta != 0:
        if balance_delta > 0:
            economy_transaction_service.record_balanced_transfer(
                db,
                tx=tx,
                currency=EconomyCurrency.COIN.value,
                amount=balance_delta,
                debit_account="SYSTEM_POOL_ADJUSTMENT:COIN",
                credit_account=f"GAME_POOL:{pool.id}:COIN",
                source_type="LUCKY_GIFT_CONTROL_POOL_ADJUSTMENT",
            )
        else:
            economy_transaction_service.record_balanced_transfer(
                db,
                tx=tx,
                currency=EconomyCurrency.COIN.value,
                amount=abs(balance_delta),
                debit_account=f"GAME_POOL:{pool.id}:COIN",
                credit_account="SYSTEM_POOL_ADJUSTMENT:COIN",
                source_type="LUCKY_GIFT_CONTROL_POOL_ADJUSTMENT",
            )
    result = {
        "transaction_id": tx.transaction_id,
        **_lucky_gift_control_pool_payload(db, pool),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_gift.control_house_pool_updated.v1",
        event_payload={
            "actor_user_id": actor.id,
            "game_key": pool.game_key,
            "pool_type": pool.pool_type,
        },
    )


@router.get("/lucky-gifts/admin/props", dependencies=[Depends(require_internal_token)])
def get_lucky_gift_props_admin(db: Session = Depends(get_db)):
    return lucky_gift_props_service.get_props(db)


@router.get("/lucky-gifts/admin/house-pool", dependencies=[Depends(require_internal_token)])
def get_lucky_gift_house_pool_admin(db: Session = Depends(get_db)):
    return lucky_gift_house_service.get_pool_detail(db)


@router.get("/lucky-gifts/admin/house-pool/list", dependencies=[Depends(require_internal_token)])
def list_lucky_gift_house_pools_admin(db: Session = Depends(get_db)):
    return {"pools": lucky_gift_house_service.list_pools(db)}


@router.get("/lucky-gifts/admin/moderation", dependencies=[Depends(require_internal_token)])
def get_lucky_gift_moderation_admin(db: Session = Depends(get_db)):
    house = lucky_gift_house_service.get_pool_detail(db)
    props = lucky_gift_props_service.get_props(db)
    latest = (
        db.query(LuckyGiftTransaction)
        .order_by(LuckyGiftTransaction.id.desc())
        .limit(30)
        .all()
    )
    high_risk = (
        db.query(LuckyGiftTransaction)
        .filter(
            (LuckyGiftTransaction.multiplier >= 100)
            | (LuckyGiftTransaction.reward_coins >= int(props["broadcast_min_reward"]))
        )
        .order_by(LuckyGiftTransaction.id.desc())
        .limit(30)
        .all()
    )
    return {
        "props": props,
        "house_pools": house,
        "latest_transactions": [_lucky_gift_transaction_payload(row) for row in latest],
        "high_risk_transactions": [
            _lucky_gift_transaction_payload(row) for row in high_risk
        ],
    }


@router.post("/lucky-gifts/admin/props", dependencies=[Depends(require_internal_token)])
def update_lucky_gift_props_admin(
    payload: LuckyGiftPropsAdminCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="lucky_gift.props.update",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached
    props = lucky_gift_props_service.update_props(
        db,
        actor,
        payload.props,
        commit=False,
    )
    result = {"transaction_id": tx.transaction_id, **props}
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_gift.props_updated.v1",
        event_payload={"actor_user_id": actor.id, "game_key": "lucky_gifts"},
    )


@router.post("/lucky-gifts/admin/house-pool/adjust", dependencies=[Depends(require_internal_token)])
def adjust_lucky_gift_pool_admin(
    payload: LuckyGiftPoolAdjustCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="lucky_gift.pool.adjust",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached
    pool = lucky_gift_house_service.adjust_pool(
        db=db,
        actor=actor,
        game_key=payload.game_key,
        pool_type=payload.pool_type,
        direction=payload.direction,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    result = {"transaction_id": tx.transaction_id, **lucky_gift_house_service.pool_response(pool)}
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_gift.pool_adjusted.v1",
        event_payload={
            "actor_user_id": actor.id,
            "pool_id": pool.id,
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
            "direction": payload.direction,
            "amount": payload.amount,
        },
    )


@router.post("/lucky-gifts/admin/house-pool/allocate", dependencies=[Depends(require_internal_token)])
def allocate_lucky_gift_pool_admin(
    payload: LuckyGiftPoolTransferCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="lucky_gift.pool.allocate",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached
    pair = lucky_gift_house_service.allocate_main_to_lucky(
        db=db,
        actor=actor,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    result = {"transaction_id": tx.transaction_id, **pair}
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_gift.pool_allocated.v1",
        event_payload={
            "actor_user_id": actor.id,
            "game_key": "lucky_gifts",
            "amount": payload.amount,
            "direction": "MAIN_TO_LUCKY",
        },
    )


@router.post("/lucky-gifts/admin/house-pool/withdraw", dependencies=[Depends(require_internal_token)])
def withdraw_lucky_gift_pool_admin(
    payload: LuckyGiftPoolTransferCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="lucky_gift.pool.withdraw",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached
    pair = lucky_gift_house_service.withdraw_lucky_to_main(
        db=db,
        actor=actor,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    result = {"transaction_id": tx.transaction_id, **pair}
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_gift.pool_withdrawn.v1",
        event_payload={
            "actor_user_id": actor.id,
            "game_key": "lucky_gifts",
            "amount": payload.amount,
            "direction": "LUCKY_TO_MAIN",
        },
    )


@router.post("/lucky-gifts/admin/house-pool/settings", dependencies=[Depends(require_internal_token)])
def update_lucky_gift_pool_settings_admin(
    payload: LuckyGiftPoolSettingsCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="lucky_gift.pool.settings",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached
    pool = lucky_gift_house_service.update_pool_settings(
        db=db,
        actor=actor,
        game_key=payload.game_key,
        pool_type=payload.pool_type,
        status=payload.status,
        daily_payout_cap=payload.daily_payout_cap,
        daily_loss_limit=payload.daily_loss_limit,
        max_single_payout=payload.max_single_payout,
        rtp_target_basis_points=payload.rtp_target_basis_points,
        reason=payload.reason,
        commit=False,
    )
    result = {"transaction_id": tx.transaction_id, **lucky_gift_house_service.pool_response(pool)}
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_gift.pool_settings_updated.v1",
        event_payload={
            "actor_user_id": actor.id,
            "pool_id": pool.id,
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
        },
    )


@router.post("/supply/mint", dependencies=[Depends(require_internal_token)])
def mint_supply(payload: SupplyMintRequest, db: Session = Depends(get_db)):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(db, payload, operation="supply.mint", actor_user_id=actor.id)
    if cached is not None:
        return cached
    pool = economy_service.mint_to_pool(
        db=db,
        actor=actor,
        target_pool_type=payload.target_pool_type,
        target_user_id=payload.target_user_id,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "id": pool.id,
        "owner_user_id": pool.owner_user_id,
        "pool_type": pool.pool_type,
        "balance": int(pool.balance or 0),
        "reserved_balance": int(pool.reserved_balance or 0),
        "status": pool.status,
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.supply.minted.v1",
        event_payload={
            "pool_id": pool.id,
            "target_pool_type": payload.target_pool_type,
            "target_user_id": payload.target_user_id,
            "amount": payload.amount,
        },
    )


@router.post("/supply/allocate", dependencies=[Depends(require_internal_token)])
def allocate_supply(payload: SupplyAllocateRequest, db: Session = Depends(get_db)):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(db, payload, operation="supply.allocate", actor_user_id=actor.id)
    if cached is not None:
        return cached
    pool = economy_service.allocate_pool_to_pool(
        db=db,
        actor=actor,
        source_pool_id=payload.source_pool_id,
        target_pool_type=payload.target_pool_type,
        target_user_id=payload.target_user_id,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "id": pool.id,
        "owner_user_id": pool.owner_user_id,
        "pool_type": pool.pool_type,
        "balance": int(pool.balance or 0),
        "reserved_balance": int(pool.reserved_balance or 0),
        "status": pool.status,
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.supply.allocated.v1",
        event_payload={
            "source_pool_id": payload.source_pool_id,
            "target_pool_id": pool.id,
            "amount": payload.amount,
        },
    )


@router.post("/supply/seller-sale", dependencies=[Depends(require_internal_token)])
def seller_sale(payload: SellerSaleCommandRequest, db: Session = Depends(get_db)):
    seller = db.query(User).filter(User.id == payload.seller_user_id).first()
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="supply.seller_sale",
        actor_user_id=seller.id,
    )
    if cached is not None:
        return cached
    order = economy_service.sell_pool_coins_to_user(
        db=db,
        seller=seller,
        buyer_user_id=payload.buyer_user_id,
        source_pool_id=payload.source_pool_id,
        coin_amount=payload.coin_amount,
        payment_amount=payload.payment_amount,
        payment_currency=payload.payment_currency,
        proof_url=payload.proof_url,
        commit=False,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "id": order.id,
        "seller_user_id": order.seller_user_id,
        "buyer_user_id": order.buyer_user_id,
        "source_pool_id": order.source_pool_id,
        "coin_amount": int(order.coin_amount or 0),
        "delivery_status": order.delivery_status,
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.seller_sale.completed.v1",
        event_payload={
            "order_id": order.id,
            "seller_user_id": order.seller_user_id,
            "buyer_user_id": order.buyer_user_id,
            "source_pool_id": order.source_pool_id,
            "coin_amount": int(order.coin_amount or 0),
        },
    )


@router.post("/recharge/official", dependencies=[Depends(require_internal_token)])
def official_recharge(
    payload: OfficialRechargeCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    if payload.target_user_id is None and payload.target_public_user_id is None:
        raise HTTPException(
            status_code=400,
            detail="target_user_id or target_public_user_id is required",
        )
    query = db.query(User)
    target = (
        query.filter(User.id == payload.target_user_id).first()
        if payload.target_user_id is not None
        else query.filter(User.public_user_id == payload.target_public_user_id).first()
    )
    if target is None:
        raise HTTPException(status_code=404, detail="Target user not found")

    tx, cached = _begin(
        db,
        payload,
        operation="recharge.official",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached

    wallet = economy_transaction_service.credit(
        db,
        user_id=target.id,
        amount=payload.coin_amount,
        currency=EconomyCurrency.COIN.value,
        source_type="OFFICIAL_RECHARGE",
        source_id=tx.transaction_id,
        reason=payload.reason,
        tx=tx,
        actor_user_id=actor.id,
        metadata_json=json.dumps(
            {
                "payment_amount": payload.payment_amount,
                "payment_currency": payload.payment_currency,
                "proof_url": payload.proof_url or "",
            },
            separators=(",", ":"),
        ),
    )
    levels = economy_level_service.wallet_level_payload(db, wallet)
    status = economy_level_service.sync_vip_status(db, target.id, levels)

    wallet_payload = {
        "user_id": target.id,
        "coin_balance": int(wallet.coin_balance or 0),
        "ruby_balance": int(wallet.ruby_balance or 0),
        "withdrawable_rubies": max(
            int(wallet.ruby_balance or 0) - int(wallet.locked_ruby_balance or 0),
            0,
        ),
        "pending_withdraw_rubies": int(wallet.pending_withdraw_rubies or 0),
        "lifetime_coins_spent": int(wallet.lifetime_coins_spent or 0),
        "lifetime_coins_received_as_gifts": int(
            wallet.lifetime_coins_received_as_gifts or 0
        ),
        "lifetime_rubies_earned": int(wallet.lifetime_rubies_earned or 0),
        "lifetime_recharge_coin_exp": levels["lifetime_recharge_coin_exp"],
        "monthly_recharge_coin_exp": levels["monthly_recharge_coin_exp"],
        "monthly_gift_coins_sent": levels["monthly_gift_coins_sent"],
        "monthly_gift_coins_received": levels["monthly_gift_coins_received"],
        "lifetime_send_exp": levels["lifetime_send_exp"],
        "lifetime_receive_exp": levels["lifetime_receive_exp"],
        "vip": levels["vip"],
        "svip": levels["svip"],
        "sent": levels["sent"],
        "received": levels["received"],
        "vip_level": int(status.vip_level or 0),
        "svip_level": int(status.svip_level or 0),
    }
    result = {
        "transaction_id": tx.transaction_id,
        "target_user_id": target.id,
        "target_public_user_id": target.public_user_id,
        "coin_amount": payload.coin_amount,
        "payment_amount": payload.payment_amount,
        "payment_currency": payload.payment_currency,
        "wallet": wallet_payload,
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.official_recharge.completed.v1",
        event_payload={
            "target_user_id": target.id,
            "target_public_user_id": target.public_user_id,
            "coin_amount": payload.coin_amount,
            "payment_amount": payload.payment_amount,
            "payment_currency": payload.payment_currency,
        },
    )


@router.post("/game-pools/configure", dependencies=[Depends(require_internal_token)])
def configure_game_pool(
    payload: GamePoolConfigureCommandRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")
    tx, cached = _begin(
        db,
        payload,
        operation="game_pool.configure",
        actor_user_id=actor.id,
    )
    if cached is not None:
        return cached

    pool = economy_service.create_game_pool(
        db=db,
        game_key=payload.game_key,
        pool_type=payload.pool_type,
        opening_balance=payload.opening_balance,
        daily_payout_cap=payload.daily_payout_cap,
        daily_loss_limit=payload.daily_loss_limit,
        max_single_payout=payload.max_single_payout,
        rtp_target_basis_points=payload.rtp_target_basis_points,
        commit=False,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "id": pool.id,
        "game_key": pool.game_key,
        "pool_type": pool.pool_type,
        "balance": int(pool.balance or 0),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.game_pool.configured.v1",
        event_payload={
            "pool_id": pool.id,
            "game_key": pool.game_key,
            "pool_type": pool.pool_type,
            "opening_balance": payload.opening_balance,
        },
    )


@router.post("/bulk-grants/enqueue", dependencies=[Depends(require_internal_token)])
def enqueue_bulk_grant(
    payload: BulkGrantEnqueueRequest,
    db: Session = Depends(get_db),
):
    actor = db.query(User).filter(User.id == payload.actor_user_id).first()
    if actor is None:
        raise HTTPException(status_code=404, detail="Actor user not found")

    job, created = economy_bulk_grant_service.create_job(
        db,
        grant_id=payload.transaction_id,
        idempotency_key=payload.idempotency_key,
        actor_user_id=payload.actor_user_id,
        coin_amount=payload.coin_amount,
        active_only=payload.active_only,
        reason=payload.reason,
    )

    if created:
        event_outbox_service.enqueue_event(
            db,
            event_type="economy.bulk_grant.queued.v1",
            actor_user_id=payload.actor_user_id,
            payload={
                "grant_id": job.grant_id,
                "coin_amount": int(job.coin_amount),
                "active_only": bool(job.active_only),
                "eligible_count": int(job.eligible_count),
                "business_reference": payload.business_reference,
            },
        )
    db.commit()

    return {
        "grant_id": job.grant_id,
        "status": job.status,
        "eligible_count": int(job.eligible_count),
        "processed_count": int(job.processed_count),
        "created": created,
    }


@router.post("/mission-rewards/claim", dependencies=[Depends(require_internal_token)])
def claim_mission_reward(
    payload: MissionRewardRequest,
    db: Session = Depends(get_db),
):
    tx, cached = _begin(
        db,
        payload,
        operation="mission.reward",
        actor_user_id=payload.user_id,
    )
    if cached is not None:
        return cached

    source_id = f"{payload.mission_id}:{payload.cycle_key}"
    existing = (
        db.query(WalletLedger.id)
        .filter(
            WalletLedger.user_id == payload.user_id,
            WalletLedger.source_type == "SOCIAL_MISSION_REWARD",
            WalletLedger.source_id == source_id,
        )
        .first()
    )
    if existing is not None:
        wallet = economy_transaction_service.wallet_for_update(db, payload.user_id)
        result = {
            "transaction_id": tx.transaction_id,
            "credited": False,
            "user_id": payload.user_id,
            "coin_balance": int(wallet.coin_balance or 0),
        }
        return economy_transaction_service.complete(
            db,
            tx=tx,
            result=result,
            event_type="economy.mission_reward_duplicate.v1",
            event_payload={
                "user_id": payload.user_id,
                "mission_id": payload.mission_id,
                "cycle_key": payload.cycle_key,
            },
        )

    wallet = economy_transaction_service.credit(
        db,
        user_id=payload.user_id,
        amount=payload.reward_coin_amount,
        currency=EconomyCurrency.COIN.value,
        source_type="SOCIAL_MISSION_REWARD",
        source_id=source_id,
        reason=f"Social mission reward: {payload.mission_id}",
        tx=tx,
        actor_user_id=payload.user_id,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "credited": True,
        "user_id": payload.user_id,
        "coin_balance": int(wallet.coin_balance or 0),
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.mission_rewarded.v1",
        event_payload={
            "user_id": payload.user_id,
            "mission_id": payload.mission_id,
            "cycle_key": payload.cycle_key,
            "amount": payload.reward_coin_amount,
        },
    )


@router.post("/game/wager", dependencies=[Depends(require_internal_token)])
def game_wager(payload: GameFinancialRequest, db: Session = Depends(get_db)):
    if payload.wager_amount <= 0:
        raise HTTPException(status_code=400, detail="wager_amount must be positive")
    tx, cached = _begin(
        db,
        payload,
        operation="game.wager",
        actor_user_id=payload.user_id,
    )
    if cached is not None:
        return cached
    wallet = economy_transaction_service.debit(
        db,
        user_id=payload.user_id,
        amount=payload.wager_amount,
        currency=EconomyCurrency.COIN.value,
        source_type="COIN_GAME_WAGER",
        source_id=payload.round_id,
        reason=f"Coin game wager: {payload.game_id}",
        tx=tx,
        actor_user_id=payload.user_id,
    )
    house_income = house_pool_service.record_house_profit_or_loss(
        db,
        pool_type="GAME_HOUSE_POOL",
        amount=payload.wager_amount,
        reference_type="COIN_GAME_WAGER_INCOME",
        reference_id=payload.round_id or payload.business_reference,
    )
    reservation_scope = (
        f"game-round:{payload.round_id}:{payload.user_id}"
        if payload.round_id
        else f"game-business:{payload.business_reference}:{payload.user_id}"
    )
    reserve = house_pool_service.reserve_house_liability(
        db,
        pool_type="GAME_HOUSE_POOL",
        amount=payload.wager_amount,
        reference_type="COIN_GAME_WAGER",
        reference_id=payload.round_id or payload.business_reference,
        reservation_key=payload.business_reference,
        release_scope=reservation_scope,
        transaction_id=tx.transaction_id,
        user_id=payload.user_id,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "game_id": payload.game_id,
        "round_id": payload.round_id,
        "wager_amount": payload.wager_amount,
        "wallet_coin_balance": int(wallet.coin_balance or 0),
        "house_reservation": reserve,
        "house_income": house_income,
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.game_wagered.v1",
        event_payload={
            "user_id": payload.user_id,
            "game_id": payload.game_id,
            "round_id": payload.round_id,
            "wager_amount": payload.wager_amount,
        },
    )


@router.post("/game/settle", dependencies=[Depends(require_internal_token)])
def game_settle(payload: GameFinancialRequest, db: Session = Depends(get_db)):
    tx, cached = _begin(
        db,
        payload,
        operation="game.settle",
        actor_user_id=payload.user_id,
    )
    if cached is not None:
        return cached

    wallet = economy_transaction_service.wallet_for_update(db, payload.user_id)
    if payload.wager_amount > 0:
        wallet = economy_transaction_service.debit(
            db,
            user_id=payload.user_id,
            amount=payload.wager_amount,
            currency=EconomyCurrency.COIN.value,
            source_type="COIN_GAME_WAGER",
            source_id=payload.round_id,
            reason=f"Coin game wager: {payload.game_id}",
            tx=tx,
            actor_user_id=payload.user_id,
        )

    capped_win = house_pool_service.cap_reward_by_house_rules(
        db,
        "GAME_HOUSE_POOL",
        payload.win_amount,
    )
    capped_win = whale_risk_service.cap_reward_by_whale_rules(
        db,
        payload.user_id,
        capped_win,
    )
    if capped_win > 0:
        wallet = economy_transaction_service.credit(
            db,
            user_id=payload.user_id,
            amount=capped_win,
            currency=EconomyCurrency.COIN.value,
            source_type="COIN_GAME_WINNING",
            source_id=payload.round_id,
            reason=f"Coin game winnings: {payload.game_id}",
            tx=tx,
            actor_user_id=payload.user_id,
        )

    house_profit_or_loss = int(payload.wager_amount) - int(capped_win)
    house_result = house_pool_service.record_house_profit_or_loss(
        db,
        pool_type="GAME_HOUSE_POOL",
        amount=house_profit_or_loss,
        reference_type="COIN_GAME_SETTLEMENT",
        reference_id=payload.round_id or payload.business_reference,
    )
    reservation_scope = (
        f"game-round:{payload.round_id}:{payload.user_id}"
        if payload.round_id
        else f"game-business:{payload.business_reference}:{payload.user_id}"
    )
    house_pool_service.release_house_liability(
        db,
        reservation_scope,
    )
    risk = whale_risk_service.calculate_whale_risk_score(db, payload.user_id)

    result = {
        "transaction_id": tx.transaction_id,
        "game_id": payload.game_id,
        "round_id": payload.round_id,
        "wager_amount": payload.wager_amount,
        "win_amount": capped_win,
        "raw_win_amount": payload.win_amount,
        "net_amount": capped_win - payload.wager_amount,
        "multiplier": payload.multiplier,
        "wallet_coin_balance": int(wallet.coin_balance or 0),
        "house_profit_or_loss": house_profit_or_loss,
        "house_result": house_result,
        "risk": risk,
        "metadata": payload.metadata,
    }
    return economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.game_settled.v1",
        event_payload={
            "user_id": payload.user_id,
            "game_id": payload.game_id,
            "round_id": payload.round_id,
            "wager_amount": payload.wager_amount,
            "win_amount": capped_win,
            "raw_win_amount": payload.win_amount,
            "multiplier": payload.multiplier,
        },
    )
