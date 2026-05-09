from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.coin_economy import CoinBalanceType
from app.models.user import User
from app.schemas.coin_economy import (
    CoinActionResponse,
    CoinConsumeRequest,
    CoinGrantRequest,
    CoinSendToUserRequest,
    CoinTransactionResponse,
    CoinWalletResponse,
)
from app.services.coin_economy_service import (
    consume_user_coins,
    founder_grant_coins,
    get_user_by_public_id,
    get_wallet,
    list_transactions,
    merchant_send_to_user,
)

router = APIRouter(prefix="/coin-economy", tags=["Coin Economy"])


@router.get("/wallet/me", response_model=CoinWalletResponse)
def get_my_coin_wallet(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_wallet(db, user=current_user)


@router.get("/wallet/user/{public_user_id}", response_model=CoinWalletResponse)
def get_user_coin_wallet(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target = get_user_by_public_id(db, public_user_id)
    return get_wallet(db, user=target)


@router.post("/super-owner/grant", response_model=CoinActionResponse)
def super_owner_grant_coins(
    payload: CoinGrantRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target = get_user_by_public_id(db, payload.target_public_user_id)
    tx = founder_grant_coins(
        db,
        actor=current_user,
        target=target,
        amount=payload.amount,
        target_balance_type=payload.target_balance_type,
        reason=payload.reason,
    )
    return CoinActionResponse(
        message="Coins granted successfully",
        transaction=tx,
        actor_wallet=get_wallet(db, user=current_user),
        target_wallet=get_wallet(db, user=target),
    )


@router.post("/merchant/send-to-user", response_model=CoinActionResponse)
def merchant_or_seller_send_to_user(
    payload: CoinSendToUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target = get_user_by_public_id(db, payload.target_public_user_id)
    tx = merchant_send_to_user(
        db,
        actor=current_user,
        target=target,
        amount=payload.amount,
        reason=payload.reason,
    )
    return CoinActionResponse(
        message="Coins sent to user successfully",
        transaction=tx,
        actor_wallet=get_wallet(db, user=current_user),
        target_wallet=get_wallet(db, user=target),
    )


@router.post("/seller/send-to-user", response_model=CoinActionResponse)
def seller_send_to_user_alias(
    payload: CoinSendToUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target = get_user_by_public_id(db, payload.target_public_user_id)
    tx = merchant_send_to_user(
        db,
        actor=current_user,
        target=target,
        amount=payload.amount,
        reason=payload.reason,
    )
    return CoinActionResponse(
        message="Coins sent to user successfully",
        transaction=tx,
        actor_wallet=get_wallet(db, user=current_user),
        target_wallet=get_wallet(db, user=target),
    )


@router.post("/consume", response_model=CoinActionResponse)
def consume_my_coins(
    payload: CoinConsumeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tx = consume_user_coins(
        db,
        actor=current_user,
        amount=payload.amount,
        reason=payload.reason,
    )
    return CoinActionResponse(
        message="Consumable coins spent successfully",
        transaction=tx,
        actor_wallet=get_wallet(db, user=current_user),
        target_wallet=None,
    )


@router.get("/transactions/me", response_model=list[CoinTransactionResponse])
def get_my_coin_transactions(
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_transactions(db, user=current_user, limit=limit)


@router.get("/balance-types")
def get_coin_balance_types():
    return {
        "balance_types": [balance_type.value for balance_type in CoinBalanceType],
        "rules": {
            "consumable": "User can spend this balance on gifts/store/games later.",
            "merchant_supply": "Merchant business supply. Can be sent to users, cannot be consumed directly.",
            "seller_supply": "Seller/reseller business supply. Can be sent to users, cannot be consumed directly.",
            "founder_supply": "Platform supply source used only by Founder/Owner grant actions.",
        },
    }
