from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool
from app.models.user import User
from app.schemas.coin_sales import (
    CoinSellerPoolResponse,
    CoinSellerSaleResponse,
    CoinSellerSellToUserRequest,
    CoinSellerSupplyGrantRequest,
)
from app.services import coin_sales_service

router = APIRouter(prefix="/coin-sales", tags=["Coin Sales"])


def _pool_response(pool: CoinSupplyPool) -> CoinSellerPoolResponse:
    return CoinSellerPoolResponse(
        id=pool.id,
        owner_user_id=pool.owner_user_id,
        pool_type=pool.pool_type,
        balance=pool.balance,
        reserved_balance=pool.reserved_balance,
        status=pool.status,
    )


def _target_identifier(public_user_id: int | None, identifier: str | None) -> str:
    if identifier is not None and identifier.strip():
        return identifier.strip()
    return str(public_user_id or "").strip()


@router.get("/my-supply-pools", response_model=list[CoinSellerPoolResponse])
def my_supply_pools(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return [_pool_response(pool) for pool in coin_sales_service.get_seller_pools(db, current_user)]


@router.post("/admin/grant-supply", response_model=CoinSellerPoolResponse)
def grant_supply_to_seller(payload: CoinSellerSupplyGrantRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    pool = coin_sales_service.grant_supply_to_seller(
        db=db,
        actor=current_user,
        target_identifier=_target_identifier(payload.target_public_user_id, payload.target_user_identifier),
        pool_type=payload.pool_type,
        amount=payload.amount,
        reason=payload.reason,
    )
    return _pool_response(pool)


@router.post("/sell-to-user", response_model=CoinSellerSaleResponse)
def sell_to_user(payload: CoinSellerSellToUserRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return CoinSellerSaleResponse(**coin_sales_service.sell_to_user(
        db=db,
        seller=current_user,
        target_identifier=_target_identifier(payload.target_public_user_id, payload.target_user_identifier),
        coin_amount=payload.coin_amount,
        payment_amount=payload.payment_amount,
        payment_currency=payload.payment_currency,
        proof_url=payload.proof_url,
        source_pool_id=payload.source_pool_id,
        reason=payload.reason,
    ))
