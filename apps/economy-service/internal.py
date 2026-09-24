from __future__ import annotations

import hmac
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.economy import EconomyCurrency, WalletLedger
from app.services import (
    economy_transaction_service,
    house_pool_service,
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


class MissionRewardRequest(MutationContext):
    user_id: int
    mission_id: str = Field(min_length=1, max_length=120)
    cycle_key: str = Field(min_length=1, max_length=120)
    reward_coin_amount: int = Field(gt=0)


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
    reserve = house_pool_service.reserve_house_liability(
        db,
        pool_type="GAME_HOUSE_POOL",
        amount=payload.wager_amount,
        reference_type="COIN_GAME_WAGER",
        reference_id=payload.round_id or payload.business_reference,
    )
    result = {
        "transaction_id": tx.transaction_id,
        "game_id": payload.game_id,
        "round_id": payload.round_id,
        "wager_amount": payload.wager_amount,
        "wallet_coin_balance": int(wallet.coin_balance or 0),
        "house_reservation": reserve,
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
    house_pool_service.release_house_liability(
        db,
        payload.round_id or payload.business_reference,
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
