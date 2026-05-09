from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool
from app.models.user import User
from app.schemas.economy import AllocatePoolCoinsRequest, EconomyPoolResponse, GamePoolCreateRequest, GameRoundCreateRequest, MintCoinsRequest, SellerSaleRequest
from app.services import economy_service

router = APIRouter(prefix="/economy/admin", tags=["Economy Admin"])


def _pool_response(pool: CoinSupplyPool) -> EconomyPoolResponse:
    return EconomyPoolResponse(
        id=pool.id,
        owner_user_id=pool.owner_user_id,
        pool_type=pool.pool_type,
        balance=pool.balance,
        reserved_balance=pool.reserved_balance,
        status=pool.status,
    )


@router.post("/mint", response_model=EconomyPoolResponse)
def mint_coins(payload: MintCoinsRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    pool = economy_service.mint_to_pool(db=db, actor=current_user, target_pool_type=payload.target_pool_type, target_user_id=payload.target_user_id, amount=payload.amount, reason=payload.reason)
    return _pool_response(pool)


@router.post("/allocate", response_model=EconomyPoolResponse)
def allocate_pool_coins(payload: AllocatePoolCoinsRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    pool = economy_service.allocate_pool_to_pool(db=db, actor=current_user, source_pool_id=payload.source_pool_id, target_pool_type=payload.target_pool_type, target_user_id=payload.target_user_id, amount=payload.amount, reason=payload.reason)
    return _pool_response(pool)


@router.post("/seller-sale")
def seller_sell_coins(payload: SellerSaleRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    order = economy_service.sell_pool_coins_to_user(db=db, seller=current_user, buyer_user_id=payload.buyer_user_id, source_pool_id=payload.source_pool_id, coin_amount=payload.coin_amount, payment_amount=payload.payment_amount, payment_currency=payload.payment_currency, proof_url=payload.proof_url)
    return {"id": order.id, "seller_user_id": order.seller_user_id, "buyer_user_id": order.buyer_user_id, "source_pool_id": order.source_pool_id, "coin_amount": order.coin_amount, "delivery_status": order.delivery_status, "note": "Supply pool coins are inventory only and never part of personal coin balance."}


@router.post("/gaming/pools")
def create_game_pool(payload: GamePoolCreateRequest, db: Session = Depends(get_db)):
    pool = economy_service.create_game_pool(db=db, game_key=payload.game_key, pool_type=payload.pool_type, opening_balance=payload.opening_balance, daily_payout_cap=payload.daily_payout_cap, daily_loss_limit=payload.daily_loss_limit, max_single_payout=payload.max_single_payout, rtp_target_basis_points=payload.rtp_target_basis_points)
    return {"id": pool.id, "game_key": pool.game_key, "pool_type": pool.pool_type, "balance": pool.balance}


@router.post("/gaming/rounds")
def create_game_round(payload: GameRoundCreateRequest, db: Session = Depends(get_db)):
    game_round = economy_service.create_game_round(db=db, game_key=payload.game_key, entry_fee=payload.entry_fee, max_players=payload.max_players, room_id=payload.room_id)
    return {"id": game_round.id, "game_key": game_round.game_key, "entry_fee": game_round.entry_fee, "status": game_round.status}
