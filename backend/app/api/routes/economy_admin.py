from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool
from app.models.user import User
from app.schemas.economy import AllocatePoolCoinsRequest, EconomyPoolResponse, GamePoolCreateRequest, GameRoundCreateRequest, MintCoinsRequest, OfficialRechargeRequest, OfficialRechargeResponse, SellerSaleRequest
from app.services import economy_level_service, economy_service, economy_service_client
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/admin/economy", tags=["Admin Economy"])


def _pool_response(pool: CoinSupplyPool) -> EconomyPoolResponse:
    return EconomyPoolResponse(
        id=pool.id,
        owner_user_id=pool.owner_user_id,
        pool_type=pool.pool_type,
        balance=pool.balance,
        reserved_balance=pool.reserved_balance,
        status=pool.status,
    )


def _wallet_response(db: Session, wallet):
    levels = economy_level_service.wallet_level_payload(db, wallet)
    economy_level_service.sync_vip_status(db, wallet.user_id, levels)
    return {
        "user_id": wallet.user_id,
        "coin_balance": wallet.coin_balance,
        "ruby_balance": wallet.ruby_balance,
        "withdrawable_rubies": max(wallet.ruby_balance - wallet.locked_ruby_balance, 0),
        "pending_withdraw_rubies": wallet.pending_withdraw_rubies,
        "lifetime_coins_spent": wallet.lifetime_coins_spent,
        "lifetime_coins_received_as_gifts": wallet.lifetime_coins_received_as_gifts,
        "lifetime_rubies_earned": wallet.lifetime_rubies_earned,
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
    }


async def _broadcast_wallet_vip_svip_update(target_user_id: int, wallet_payload: dict) -> None:
    await inbox_ws_manager.send_to_user(
        target_user_id,
        {
            "event": "wallet_vip_svip_updated",
            "payload": {
                "wallet": wallet_payload,
                "vip": wallet_payload.get("vip"),
                "svip": wallet_payload.get("svip"),
                "coin_balance": wallet_payload.get("coin_balance"),
                "lifetime_recharge_coin_exp": wallet_payload.get("lifetime_recharge_coin_exp"),
                "monthly_recharge_coin_exp": wallet_payload.get("monthly_recharge_coin_exp"),
            },
        },
    )


@router.post("/mint", response_model=EconomyPoolResponse)
def mint_coins(payload: MintCoinsRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.mint_supply(
            request_id=request_id,
            actor_user_id=current_user.id,
            target_pool_type=payload.target_pool_type,
            target_user_id=payload.target_user_id,
            amount=payload.amount,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return EconomyPoolResponse(**result)


@router.post("/allocate", response_model=EconomyPoolResponse)
def allocate_pool_coins(payload: AllocatePoolCoinsRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.allocate_supply(
            request_id=request_id,
            actor_user_id=current_user.id,
            source_pool_id=payload.source_pool_id,
            target_pool_type=payload.target_pool_type,
            target_user_id=payload.target_user_id,
            amount=payload.amount,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return EconomyPoolResponse(**result)


@router.post("/official-recharge", response_model=OfficialRechargeResponse)
def official_recharge_wallet(
    payload: OfficialRechargeRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = economy_level_service.credit_official_recharge(
        db=db,
        actor=current_user,
        target_user_id=payload.target_user_id,
        target_public_user_id=payload.target_public_user_id,
        coin_amount=payload.coin_amount,
        payment_amount=payload.payment_amount,
        payment_currency=payload.payment_currency,
        reason=payload.reason,
        proof_url=payload.proof_url,
    )
    target = result["target"]
    wallet_payload = _wallet_response(db, result["wallet"])
    background_tasks.add_task(
        _broadcast_wallet_vip_svip_update,
        target.id,
        wallet_payload,
    )
    return OfficialRechargeResponse(
        order_id=None,
        target_user_id=target.id,
        target_public_user_id=target.public_user_id,
        coin_amount=payload.coin_amount,
        payment_amount=payload.payment_amount,
        payment_currency=payload.payment_currency,
        wallet=wallet_payload,
        rule="Official recharge credited to wallet, counted toward VIP lifetime EXP + SVIP monthly EXP, and broadcast instantly to the user session.",
    )


@router.post("/seller-sale")
def seller_sell_coins(payload: SellerSaleRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    order = economy_service.sell_pool_coins_to_user(db=db, seller=current_user, buyer_user_id=payload.buyer_user_id, source_pool_id=payload.source_pool_id, coin_amount=payload.coin_amount, payment_amount=payload.payment_amount, payment_currency=payload.payment_currency, proof_url=payload.proof_url)
    return {"id": order.id, "seller_user_id": order.seller_user_id, "buyer_user_id": order.buyer_user_id, "source_pool_id": order.source_pool_id, "coin_amount": order.coin_amount, "delivery_status": order.delivery_status, "note": "Supply pool coins are inventory only and never part of personal coin balance. Seller sale coin credits count toward VIP/SVIP via recharge ledger source type."}


@router.post("/gaming/pools")
def create_game_pool(payload: GamePoolCreateRequest, db: Session = Depends(get_db)):
    pool = economy_service.create_game_pool(db=db, game_key=payload.game_key, pool_type=payload.pool_type, opening_balance=payload.opening_balance, daily_payout_cap=payload.daily_payout_cap, daily_loss_limit=payload.daily_loss_limit, max_single_payout=payload.max_single_payout, rtp_target_basis_points=payload.rtp_target_basis_points)
    return {"id": pool.id, "game_key": pool.game_key, "pool_type": pool.pool_type, "balance": pool.balance}


@router.post("/gaming/rounds")
def create_game_round(payload: GameRoundCreateRequest, db: Session = Depends(get_db)):
    game_round = economy_service.create_game_round(db=db, game_key=payload.game_key, entry_fee=payload.entry_fee, max_players=payload.max_players, room_id=payload.room_id)
    return {"id": game_round.id, "game_key": game_round.game_key, "entry_fee": game_round.entry_fee, "status": game_round.status}
