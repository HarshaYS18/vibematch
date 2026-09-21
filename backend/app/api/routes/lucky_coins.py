from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.user import User
from app.schemas.lucky_coins import (
    LuckyCoinSettleRequest,
    LuckyCoinSettleResponse,
    LuckyCoinWagerRequest,
    LuckyCoinWagerResponse,
)
from app.services import house_pool_service

router = APIRouter(prefix="/economy/lucky-coins", tags=["Lucky Coins"])


def _get_or_create_wallet_for_update(db: Session, user_id: int) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).with_for_update().first()
    if wallet is not None:
        return wallet
    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


def _debit_coin_balance(db: Session, *, user_id: int, amount: int, reference_id: str) -> UserWallet:
    wallet = _get_or_create_wallet_for_update(db, user_id)
    before = int(wallet.coin_balance or 0)
    if before < amount:
        from fastapi import HTTPException

        raise HTTPException(status_code=400, detail="Insufficient coins. Please recharge.")
    wallet.coin_balance = before - amount
    wallet.lifetime_coins_spent += amount
    db.add(
        WalletLedger(
            user_id=user_id,
            currency_type=EconomyCurrency.COIN.value,
            direction=EconomyDirection.DEBIT.value,
            amount=amount,
            before_balance=before,
            after_balance=wallet.coin_balance,
            source_type="LUCKY_COIN_WAGER",
            source_id=reference_id,
            created_by_user_id=user_id,
            reason="Lucky coin wager using regular coin balance",
        )
    )
    db.flush()
    return wallet


def _credit_coin_balance(db: Session, *, user_id: int, amount: int, reference_id: str) -> UserWallet:
    wallet = _get_or_create_wallet_for_update(db, user_id)
    if amount <= 0:
        return wallet
    before = int(wallet.coin_balance or 0)
    wallet.coin_balance = before + amount
    db.add(
        WalletLedger(
            user_id=user_id,
            currency_type=EconomyCurrency.COIN.value,
            direction=EconomyDirection.CREDIT.value,
            amount=amount,
            before_balance=before,
            after_balance=wallet.coin_balance,
            source_type="LUCKY_COIN_SETTLE_REWARD",
            source_id=reference_id,
            created_by_user_id=user_id,
            reason="Lucky coin settlement reward using regular coin balance",
        )
    )
    db.flush()
    return wallet


@router.post("/wager", response_model=LuckyCoinWagerResponse)
def create_lucky_coin_wager(
    payload: LuckyCoinWagerRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reference_id = f"lucky_coin:{current_user.id}:{payload.gift_id or 'generic'}:{payload.wager_amount}"
    try:
        wallet = _debit_coin_balance(db, user_id=current_user.id, amount=payload.wager_amount, reference_id=reference_id)
        reservation = house_pool_service.reserve_house_liability(
            db,
            pool_type="GAME_HOUSE_POOL",
            amount=payload.wager_amount,
            reference_type="LUCKY_COIN_WAGER",
            reference_id=reference_id,
        )
        db.commit()
        db.refresh(wallet)
    except Exception:
        db.rollback()
        raise
    return LuckyCoinWagerResponse(
        reference_id=reference_id,
        user_id=current_user.id,
        gift_id=payload.gift_id,
        room_public_id=payload.room_public_id,
        receiver_public_user_id=payload.receiver_public_user_id,
        wager_amount=payload.wager_amount,
        wallet_coin_balance=wallet.coin_balance,
        house_reservation=reservation,
        rule="Current beta behavior: wager is deducted from regular UserWallet.coin_balance. No separate lucky coin wallet exists yet.",
    )


@router.post("/settle", response_model=LuckyCoinSettleResponse)
def settle_lucky_coin_wager(
    payload: LuckyCoinSettleRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reward_amount = house_pool_service.cap_reward_by_house_rules(db, "GAME_HOUSE_POOL", payload.reward_amount)
    try:
        wallet = _credit_coin_balance(db, user_id=current_user.id, amount=reward_amount, reference_id=payload.reference_id)
        house_profit_or_loss = int(payload.wager_amount or 0) - reward_amount
        house_pool_service.record_house_profit_or_loss(
            db,
            pool_type="GAME_HOUSE_POOL",
            amount=house_profit_or_loss,
            reference_type="LUCKY_COIN_SETTLE",
            reference_id=payload.reference_id,
        )
        house_pool_service.release_house_liability(db, payload.reference_id)
        db.commit()
        db.refresh(wallet)
    except Exception:
        db.rollback()
        raise
    return LuckyCoinSettleResponse(
        reference_id=payload.reference_id,
        user_id=current_user.id,
        gift_id=payload.gift_id,
        room_public_id=payload.room_public_id,
        receiver_public_user_id=payload.receiver_public_user_id,
        wager_amount=payload.wager_amount,
        reward_amount=reward_amount,
        multiplier=payload.multiplier,
        net_win_coins=reward_amount - int(payload.wager_amount or 0),
        wallet_coin_balance=wallet.coin_balance,
        house_profit_or_loss=int(payload.wager_amount or 0) - reward_amount,
        rule="Current beta behavior: settlement reward is credited to regular UserWallet.coin_balance. No separate lucky coin wallet exists yet.",
    )
