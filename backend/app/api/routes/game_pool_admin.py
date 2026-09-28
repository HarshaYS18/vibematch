from uuid import uuid4

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyCurrency
from app.models.user import User
from app.schemas.game_pools import (
    GamePoolAdjustRequest,
    GamePoolPairResponse,
    GamePoolResponse,
    GamePoolSettingsRequest,
    GamePoolTransferRequest,
)
from app.services import (
    economy_service_client,
    economy_transaction_service,
    game_pool_service,
)
from app.services.audit_log_service import create_admin_log

router = APIRouter(prefix="/admin/games/pools", tags=["Admin Game Pools"])


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


@router.get("", response_model=list[GamePoolResponse])
def list_game_pools(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    game_pool_service.ensure_main_and_game_pools(db, "jackpot_king")
    return [GamePoolResponse(**item) for item in game_pool_service.list_pools(db)]


@router.get("/{game_key}", response_model=GamePoolPairResponse)
def get_game_pool_pair(
    game_key: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    return GamePoolPairResponse(**game_pool_service.get_pool_detail(db, game_key))


@router.post("/adjust", response_model=GamePoolResponse)
def adjust_game_pool(
    payload: GamePoolAdjustRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    business_reference = f"game-pool-adjust:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="game_pool.adjust",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={"actor_user_id": current_user.id, **payload.model_dump()},
    )
    if cached is not None:
        return GamePoolResponse(**cached)

    pool = game_pool_service.adjust_pool(
        db=db,
        actor=current_user,
        game_key=payload.game_key,
        pool_type=payload.pool_type,
        direction=payload.direction,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    pool_account = f"GAME_POOL:{pool.id}:COIN"
    if payload.direction == "CREDIT":
        economy_transaction_service.record_balanced_transfer(
            db,
            tx=tx,
            currency=EconomyCurrency.COIN.value,
            amount=payload.amount,
            debit_account="SYSTEM_POOL_ADJUSTMENT:COIN",
            credit_account=pool_account,
            source_type="SUPER_OWNER_POOL_ADJUSTMENT",
        )
    else:
        economy_transaction_service.record_balanced_transfer(
            db,
            tx=tx,
            currency=EconomyCurrency.COIN.value,
            amount=payload.amount,
            debit_account=pool_account,
            credit_account="SYSTEM_POOL_ADJUSTMENT:COIN",
            source_type="SUPER_OWNER_POOL_ADJUSTMENT",
        )
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_GAME_POOL_ADJUSTED",
        resource_type="game_pool",
        resource_id=str(pool.id),
        reason=payload.reason,
        metadata_json={
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
            "direction": payload.direction,
            "amount": payload.amount,
            "economy_transaction_id": tx.transaction_id,
        },
        commit=False,
    )
    result = GamePoolResponse(**game_pool_service._pool_response(pool)).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.game_pool.adjusted.v1",
        event_payload={
            "pool_id": pool.id,
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
            "direction": payload.direction,
            "amount": payload.amount,
        },
    )
    return GamePoolResponse(**result)


@router.post("/allocate", response_model=GamePoolPairResponse)
def allocate_main_to_game(
    payload: GamePoolTransferRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    business_reference = f"game-pool-allocate:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="game_pool.allocate",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={"actor_user_id": current_user.id, **payload.model_dump()},
    )
    if cached is not None:
        return GamePoolPairResponse(**cached)

    result = game_pool_service.allocate_from_main_to_game(
        db=db,
        actor=current_user,
        game_key=payload.game_key,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    main_id = int(result["main_pool"]["id"])
    game_id = int(result["game_pool"]["id"])
    economy_transaction_service.record_balanced_transfer(
        db,
        tx=tx,
        currency=EconomyCurrency.COIN.value,
        amount=payload.amount,
        debit_account=f"GAME_POOL:{main_id}:COIN",
        credit_account=f"GAME_POOL:{game_id}:COIN",
        source_type="POOL_ALLOCATE_TO_GAME",
    )
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_GAME_POOL_ALLOCATED",
        resource_type="game_pool",
        resource_id=str(game_id),
        reason=payload.reason,
        metadata_json={
            "game_key": payload.game_key,
            "amount": payload.amount,
            "direction": "MAIN_TO_GAME",
            "economy_transaction_id": tx.transaction_id,
        },
        commit=False,
    )
    response = GamePoolPairResponse(**result).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=response,
        event_type="economy.game_pool.allocated.v1",
        event_payload={
            "game_key": payload.game_key,
            "main_pool_id": main_id,
            "game_pool_id": game_id,
            "amount": payload.amount,
        },
    )
    return GamePoolPairResponse(**response)


@router.post("/withdraw", response_model=GamePoolPairResponse)
def withdraw_game_to_main(
    payload: GamePoolTransferRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    business_reference = f"game-pool-withdraw:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="game_pool.withdraw",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={"actor_user_id": current_user.id, **payload.model_dump()},
    )
    if cached is not None:
        return GamePoolPairResponse(**cached)

    result = game_pool_service.withdraw_from_game_to_main(
        db=db,
        actor=current_user,
        game_key=payload.game_key,
        amount=payload.amount,
        reason=payload.reason,
        commit=False,
    )
    main_id = int(result["main_pool"]["id"])
    game_id = int(result["game_pool"]["id"])
    economy_transaction_service.record_balanced_transfer(
        db,
        tx=tx,
        currency=EconomyCurrency.COIN.value,
        amount=payload.amount,
        debit_account=f"GAME_POOL:{game_id}:COIN",
        credit_account=f"GAME_POOL:{main_id}:COIN",
        source_type="POOL_WITHDRAW_TO_MAIN",
    )
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_GAME_POOL_WITHDRAWN",
        resource_type="game_pool",
        resource_id=str(game_id),
        reason=payload.reason,
        metadata_json={
            "game_key": payload.game_key,
            "amount": payload.amount,
            "direction": "GAME_TO_MAIN",
            "economy_transaction_id": tx.transaction_id,
        },
        commit=False,
    )
    response = GamePoolPairResponse(**result).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=response,
        event_type="economy.game_pool.withdrawn.v1",
        event_payload={
            "game_key": payload.game_key,
            "main_pool_id": main_id,
            "game_pool_id": game_id,
            "amount": payload.amount,
        },
    )
    return GamePoolPairResponse(**response)


@router.post("/settings", response_model=GamePoolResponse)
def update_game_pool_settings(
    payload: GamePoolSettingsRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    business_reference = f"game-pool-settings:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="game_pool.settings",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={"actor_user_id": current_user.id, **payload.model_dump()},
    )
    if cached is not None:
        return GamePoolResponse(**cached)

    pool = game_pool_service.update_pool_settings(
        db=db,
        actor=current_user,
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
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_GAME_POOL_SETTINGS_UPDATED",
        resource_type="game_pool",
        resource_id=str(pool.id),
        reason=payload.reason,
        metadata_json={
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
            "status": payload.status,
            "daily_payout_cap": payload.daily_payout_cap,
            "daily_loss_limit": payload.daily_loss_limit,
            "max_single_payout": payload.max_single_payout,
            "rtp_target_basis_points": payload.rtp_target_basis_points,
            "economy_transaction_id": tx.transaction_id,
        },
        commit=False,
    )
    result = GamePoolResponse(**game_pool_service._pool_response(pool)).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.game_pool.settings_updated.v1",
        event_payload={
            "pool_id": pool.id,
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
        },
    )
    return GamePoolResponse(**result)
