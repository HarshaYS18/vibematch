from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyCurrency
from app.models.user import User
from app.schemas.lucky_coins import (
    LuckyCoinSettleRequest,
    LuckyCoinSettleResponse,
    LuckyCoinWagerRequest,
    LuckyCoinWagerResponse,
)
from app.services import (
    economy_service_client,
    economy_transaction_service,
    house_pool_service,
)

router = APIRouter(prefix="/economy/lucky-coins", tags=["Lucky Coins"])


def _begin_public(
    db: Session,
    *,
    operation: str,
    business_reference: str,
    actor_user_id: int,
    request_payload: dict,
):
    context = economy_service_client.mutation_context(operation, business_reference)
    tx, cached = economy_transaction_service.begin(
        db,
        transaction_id=context["transaction_id"],
        idempotency_key=context["idempotency_key"],
        business_reference=context["business_reference"],
        operation_type=operation,
        actor_user_id=actor_user_id,
        request_payload=request_payload,
    )
    return tx, cached


@router.post("/wager", response_model=LuckyCoinWagerResponse)
def create_lucky_coin_wager(
    payload: LuckyCoinWagerRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    request_id = (payload.request_id or str(uuid4())).strip()
    reference_id = f"lucky_coin:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="lucky_coin.wager",
        business_reference=reference_id,
        actor_user_id=current_user.id,
        request_payload={
            "user_id": current_user.id,
            **payload.model_dump(),
            "request_id": request_id,
        },
    )
    if cached is not None:
        return LuckyCoinWagerResponse(**cached)

    wallet = economy_transaction_service.debit(
        db,
        user_id=current_user.id,
        amount=payload.wager_amount,
        currency=EconomyCurrency.COIN.value,
        source_type="LUCKY_COIN_WAGER",
        source_id=reference_id,
        reason="Lucky coin wager using regular coin balance",
        tx=tx,
        actor_user_id=current_user.id,
    )
    reservation = house_pool_service.reserve_house_liability(
        db,
        pool_type="GAME_HOUSE_POOL",
        amount=payload.wager_amount,
        reference_type="LUCKY_COIN_WAGER",
        reference_id=reference_id,
        reservation_key=reference_id,
        release_scope=reference_id,
        transaction_id=tx.transaction_id,
        user_id=current_user.id,
    )
    result = LuckyCoinWagerResponse(
        reference_id=reference_id,
        user_id=current_user.id,
        gift_id=payload.gift_id,
        room_public_id=payload.room_public_id,
        receiver_public_user_id=payload.receiver_public_user_id,
        wager_amount=payload.wager_amount,
        wallet_coin_balance=int(wallet.coin_balance or 0),
        house_reservation=reservation,
        rule="Wager is deducted from regular UserWallet.coin_balance. No separate lucky coin wallet exists.",
    ).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_coin.wagered.v1",
        event_payload={
            "user_id": current_user.id,
            "reference_id": reference_id,
            "wager_amount": payload.wager_amount,
        },
    )
    return LuckyCoinWagerResponse(**result)


@router.post("/settle", response_model=LuckyCoinSettleResponse)
def settle_lucky_coin_wager(
    payload: LuckyCoinSettleRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    settle_request_id = (payload.request_id or payload.reference_id).strip()
    business_reference = f"lucky_coin_settle:{current_user.id}:{settle_request_id}"
    tx, cached = _begin_public(
        db,
        operation="lucky_coin.settle",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={"user_id": current_user.id, **payload.model_dump()},
    )
    if cached is not None:
        return LuckyCoinSettleResponse(**cached)

    reward_amount = house_pool_service.cap_reward_by_house_rules(
        db,
        "GAME_HOUSE_POOL",
        payload.reward_amount,
    )
    wallet = economy_transaction_service.wallet_for_update(db, current_user.id)
    if reward_amount > 0:
        wallet = economy_transaction_service.credit(
            db,
            user_id=current_user.id,
            amount=reward_amount,
            currency=EconomyCurrency.COIN.value,
            source_type="LUCKY_COIN_SETTLE_REWARD",
            source_id=payload.reference_id,
            reason="Lucky coin settlement reward using regular coin balance",
            tx=tx,
            actor_user_id=current_user.id,
        )

    house_profit_or_loss = int(payload.wager_amount or 0) - reward_amount
    house_result = house_pool_service.record_house_profit_or_loss(
        db,
        pool_type="GAME_HOUSE_POOL",
        amount=house_profit_or_loss,
        reference_type="LUCKY_COIN_SETTLE",
        reference_id=payload.reference_id,
    )
    if house_result.get("recorded"):
        amount = abs(int(house_profit_or_loss))
        pool_account = f"GAME_POOL:{int(house_result['pool_id'])}:COIN"
        if house_profit_or_loss > 0:
            economy_transaction_service.record_balanced_transfer(
                db,
                tx=tx,
                currency=EconomyCurrency.COIN.value,
                amount=amount,
                debit_account="SYSTEM_CLEARING:LUCKY_COIN_SETTLE:COIN",
                credit_account=pool_account,
                source_type="LUCKY_COIN_SETTLE",
            )
        elif house_profit_or_loss < 0:
            economy_transaction_service.record_balanced_transfer(
                db,
                tx=tx,
                currency=EconomyCurrency.COIN.value,
                amount=amount,
                debit_account=pool_account,
                credit_account="SYSTEM_CLEARING:LUCKY_COIN_SETTLE:COIN",
                source_type="LUCKY_COIN_SETTLE",
            )

    release = house_pool_service.release_house_liability(db, payload.reference_id)
    result = LuckyCoinSettleResponse(
        reference_id=payload.reference_id,
        user_id=current_user.id,
        gift_id=payload.gift_id,
        room_public_id=payload.room_public_id,
        receiver_public_user_id=payload.receiver_public_user_id,
        wager_amount=payload.wager_amount,
        reward_amount=reward_amount,
        multiplier=payload.multiplier,
        net_win_coins=reward_amount - int(payload.wager_amount or 0),
        wallet_coin_balance=int(wallet.coin_balance or 0),
        house_profit_or_loss=house_profit_or_loss,
        rule="Settlement reward is credited to regular UserWallet.coin_balance. No separate lucky coin wallet exists.",
    ).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_coin.settled.v1",
        event_payload={
            "user_id": current_user.id,
            "reference_id": payload.reference_id,
            "wager_amount": payload.wager_amount,
            "reward_amount": reward_amount,
            "house_profit_or_loss": house_profit_or_loss,
            "released_reservation_amount": int(release.get("released_amount") or 0),
        },
    )
    return LuckyCoinSettleResponse(**result)
