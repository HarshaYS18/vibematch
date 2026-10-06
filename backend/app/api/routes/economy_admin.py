from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool
from app.models.user import User
from app.schemas.economy import AllocatePoolCoinsRequest, EconomyPoolResponse, GamePoolCreateRequest, GameRoundCreateRequest, MintCoinsRequest, OfficialRechargeRequest, OfficialRechargeResponse, SellerSaleRequest
from app.services import economy_service_client, game_platform_service_client
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
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.official_recharge(
            request_id=request_id,
            actor_user_id=current_user.id,
            target_user_id=payload.target_user_id,
            target_public_user_id=payload.target_public_user_id,
            coin_amount=payload.coin_amount,
            payment_amount=payload.payment_amount,
            payment_currency=payload.payment_currency,
            reason=payload.reason,
            proof_url=payload.proof_url,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    wallet_payload = dict(result["wallet"])
    target_user_id = int(result["target_user_id"])
    background_tasks.add_task(
        _broadcast_wallet_vip_svip_update,
        target_user_id,
        wallet_payload,
    )
    return OfficialRechargeResponse(
        order_id=None,
        target_user_id=target_user_id,
        target_public_user_id=int(result["target_public_user_id"]),
        coin_amount=int(result["coin_amount"]),
        payment_amount=int(result["payment_amount"]),
        payment_currency=str(result["payment_currency"]),
        wallet=wallet_payload,
        rule="Official recharge credited to wallet, counted toward VIP lifetime EXP + SVIP monthly EXP, and broadcast instantly to the user session.",
    )

@router.post("/seller-sale")
def seller_sell_coins(payload: SellerSaleRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.seller_sale(
            request_id=request_id,
            seller_user_id=current_user.id,
            buyer_user_id=payload.buyer_user_id,
            source_pool_id=payload.source_pool_id,
            coin_amount=payload.coin_amount,
            payment_amount=payload.payment_amount,
            payment_currency=payload.payment_currency,
            proof_url=payload.proof_url,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return {
        "id": int(result["id"]),
        "seller_user_id": int(result["seller_user_id"]),
        "buyer_user_id": int(result["buyer_user_id"]),
        "source_pool_id": int(result["source_pool_id"]),
        "coin_amount": int(result["coin_amount"]),
        "delivery_status": str(result["delivery_status"]),
        "note": "Supply pool coins are inventory only and never part of personal coin balance. Seller sale coin credits count toward VIP/SVIP via recharge ledger source type.",
    }


@router.post("/gaming/pools")
def create_game_pool(
    payload: GamePoolCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.configure_game_pool(
            request_id=request_id,
            actor_user_id=current_user.id,
            game_key=payload.game_key,
            pool_type=payload.pool_type,
            opening_balance=payload.opening_balance,
            daily_payout_cap=payload.daily_payout_cap,
            daily_loss_limit=payload.daily_loss_limit,
            max_single_payout=payload.max_single_payout,
            rtp_target_basis_points=payload.rtp_target_basis_points,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return {
        "id": int(result["id"]),
        "game_key": str(result["game_key"]),
        "pool_type": str(result["pool_type"]),
        "balance": int(result["balance"]),
    }


@router.post("/gaming/rounds")
def create_game_round(
    payload: GameRoundCreateRequest,
    current_user: User = Depends(get_current_user),
    authorization: str | None = Header(default=None),
):
    require_super_owner(current_user)
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header is required")
    try:
        result = game_platform_service_client.create_round(
            authorization=authorization,
            game_key=payload.game_key,
            room_id=payload.room_id,
        )
    except game_platform_service_client.GamePlatformServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except game_platform_service_client.GamePlatformServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return {
        "id": int(result["id"]),
        "game_key": str(result["game_key"]),
        "entry_fee": int(result.get("entry_fee") or 0),
        "max_players": int(result.get("max_players") or payload.max_players),
        "room_id": result.get("room_id"),
        "status": str(result["status"]),
        "note": "Round lifecycle is owned by Game Platform; legacy entry_fee/max_players inputs do not override authoritative game configuration.",
    }
