from uuid import uuid4

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool, EconomyCurrency
from app.models.user import User
from app.schemas.coin_sales import (
    CoinSellerPoolResponse,
    CoinSellerSaleResponse,
    CoinSellerSellToUserRequest,
    CoinSellerSupplyGrantRequest,
)
from app.services import (
    coin_sales_service,
    economy_service_client,
    economy_transaction_service,
)

router = APIRouter(prefix="/coin-sales", tags=["Coin Sales"])
admin_router = APIRouter(prefix="/admin/economy/coin-sales", tags=["Admin Coin Sales"])


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


def _begin_public(
    db: Session,
    *,
    operation: str,
    business_reference: str,
    actor_user_id: int,
    request_payload: dict,
):
    context = economy_service_client.mutation_context(operation, business_reference)
    return economy_transaction_service.begin(
        db,
        transaction_id=context["transaction_id"],
        idempotency_key=context["idempotency_key"],
        business_reference=context["business_reference"],
        operation_type=operation,
        actor_user_id=actor_user_id,
        request_payload=request_payload,
    )


@router.get("/my-supply-pools", response_model=list[CoinSellerPoolResponse])
def my_supply_pools(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return [
        _pool_response(pool)
        for pool in coin_sales_service.get_seller_pools(db, current_user)
    ]


@admin_router.post("/grant-supply", response_model=CoinSellerPoolResponse)
def grant_supply_to_seller(
    payload: CoinSellerSupplyGrantRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    request_id = (payload.request_id or str(uuid4())).strip()
    business_reference = f"seller-supply-grant:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="supply.seller_grant",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={"actor_user_id": current_user.id, **payload.model_dump()},
    )
    if cached is not None:
        return CoinSellerPoolResponse(**cached)

    pool = coin_sales_service.grant_supply_to_seller(
        db=db,
        actor=current_user,
        target_identifier=_target_identifier(
            payload.target_public_user_id,
            payload.target_user_identifier,
        ),
        pool_type=payload.pool_type,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    economy_transaction_service.record_balanced_transfer(
        db,
        tx=tx,
        currency=EconomyCurrency.COIN.value,
        amount=payload.amount,
        debit_account="SYSTEM_SUPPLY_GRANT:COIN",
        credit_account=f"SUPPLY_POOL:{pool.id}:COIN",
        source_type="SELLER_SUPPLY_GRANT",
        credit_user_id=pool.owner_user_id,
    )
    result = _pool_response(pool).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.seller_supply_granted.v1",
        event_payload={
            "pool_id": pool.id,
            "owner_user_id": pool.owner_user_id,
            "pool_type": pool.pool_type,
            "amount": payload.amount,
        },
    )
    return CoinSellerPoolResponse(**result)


@router.post("/sell-to-user", response_model=CoinSellerSaleResponse)
def sell_to_user(
    payload: CoinSellerSellToUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    request_id = (payload.request_id or str(uuid4())).strip()
    business_reference = f"role-coin-sale:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="supply.role_coin_sale",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={"seller_user_id": current_user.id, **payload.model_dump()},
    )
    if cached is not None:
        return CoinSellerSaleResponse(**cached)

    result = coin_sales_service.sell_to_user(
        db=db,
        seller=current_user,
        target_identifier=_target_identifier(
            payload.target_public_user_id,
            payload.target_user_identifier,
        ),
        coin_amount=payload.coin_amount,
        payment_amount=payload.payment_amount,
        payment_currency=payload.payment_currency,
        proof_url=payload.proof_url,
        source_pool_id=payload.source_pool_id,
        reason=payload.reason,
        tx=tx,
        commit=False,
    )
    economy_transaction_service.record_balanced_transfer(
        db,
        tx=tx,
        currency=EconomyCurrency.COIN.value,
        amount=payload.coin_amount,
        debit_account=f"SUPPLY_POOL:{int(result['source_pool_id'])}:COIN",
        credit_account="SYSTEM_CLEARING:ROLE_COIN_SALE:COIN",
        source_type="ROLE_COIN_SALE",
        debit_user_id=current_user.id,
    )
    response = CoinSellerSaleResponse(**result).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=response,
        event_type="economy.role_coin_sale.completed.v1",
        event_payload={
            "order_id": int(result["order_id"]),
            "seller_user_id": current_user.id,
            "buyer_user_id": int(result["buyer_user_id"]),
            "source_pool_id": int(result["source_pool_id"]),
            "coin_amount": payload.coin_amount,
        },
    )
    return CoinSellerSaleResponse(**response)
