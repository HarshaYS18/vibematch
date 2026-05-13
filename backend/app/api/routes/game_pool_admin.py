from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.game_pools import (
    GamePoolAdjustRequest,
    GamePoolPairResponse,
    GamePoolResponse,
    GamePoolSettingsRequest,
    GamePoolTransferRequest,
)
from app.services import game_pool_service
from app.services.audit_log_service import create_admin_log

router = APIRouter(prefix="/super-owner/game-pools", tags=["Super Owner Game Pools"])


@router.get("", response_model=list[GamePoolResponse])
def list_game_pools(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    game_pool_service.ensure_main_and_game_pools(db, "jackpot_king")
    return [GamePoolResponse(**item) for item in game_pool_service.list_pools(db)]


@router.get("/{game_key}", response_model=GamePoolPairResponse)
def get_game_pool_pair(game_key: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    return GamePoolPairResponse(**game_pool_service.get_pool_detail(db, game_key))


@router.post("/adjust", response_model=GamePoolResponse)
def adjust_game_pool(payload: GamePoolAdjustRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    pool = game_pool_service.adjust_pool(
        db=db,
        actor=current_user,
        game_key=payload.game_key,
        pool_type=payload.pool_type,
        direction=payload.direction,
        amount=payload.amount,
        reason=payload.reason,
    )
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_GAME_POOL_ADJUSTED",
        resource_type="game_pool",
        resource_id=str(pool.id),
        reason=payload.reason,
        metadata_json={"game_key": payload.game_key, "pool_type": payload.pool_type, "direction": payload.direction, "amount": payload.amount},
    )
    return GamePoolResponse(**game_pool_service._pool_response(pool))


@router.post("/allocate", response_model=GamePoolPairResponse)
def allocate_main_to_game(payload: GamePoolTransferRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    result = game_pool_service.allocate_from_main_to_game(db=db, actor=current_user, game_key=payload.game_key, amount=payload.amount, reason=payload.reason)
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_GAME_POOL_ALLOCATED",
        resource_type="game_pool",
        reason=payload.reason,
        metadata_json={"game_key": payload.game_key, "amount": payload.amount, "direction": "MAIN_TO_GAME"},
    )
    return GamePoolPairResponse(**result)


@router.post("/withdraw", response_model=GamePoolPairResponse)
def withdraw_game_to_main(payload: GamePoolTransferRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    result = game_pool_service.withdraw_from_game_to_main(db=db, actor=current_user, game_key=payload.game_key, amount=payload.amount, reason=payload.reason)
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_GAME_POOL_WITHDRAWN",
        resource_type="game_pool",
        reason=payload.reason,
        metadata_json={"game_key": payload.game_key, "amount": payload.amount, "direction": "GAME_TO_MAIN"},
    )
    return GamePoolPairResponse(**result)


@router.post("/settings", response_model=GamePoolResponse)
def update_game_pool_settings(payload: GamePoolSettingsRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
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
        },
    )
    return GamePoolResponse(**game_pool_service._pool_response(pool))
