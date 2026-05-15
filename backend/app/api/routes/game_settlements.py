from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.game_settlements import (
    GameSettleRequest,
    GameSettleResponse,
    GameWagerRequest,
    GameWagerResponse,
    GameWinningsToWalletRequest,
    GameWinningsToWalletResponse,
)
from app.services import game_settlement_service

router = APIRouter(prefix="/games", tags=["Game Settlements"])


@router.post("/wager", response_model=GameWagerResponse)
def create_game_wager(
    payload: GameWagerRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = game_settlement_service.create_coin_game_wager(
        db,
        user_id=current_user.id,
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=payload.wager_amount,
        metadata=payload.metadata,
    )
    return GameWagerResponse(**result)


@router.post("/settle", response_model=GameSettleResponse)
def settle_game_round(
    payload: GameSettleRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = game_settlement_service.settle_coin_game_to_regular_wallet(
        db,
        user_id=current_user.id,
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=payload.wager_amount,
        win_amount=payload.win_amount,
        multiplier=payload.multiplier,
        metadata=payload.metadata,
    )
    db.commit()
    return GameSettleResponse(**result)


@router.post("/settle-winnings-to-wallet", response_model=GameWinningsToWalletResponse)
def settle_game_winnings_to_wallet(
    payload: GameWinningsToWalletRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = game_settlement_service.settle_coin_game_to_regular_wallet(
        db,
        user_id=current_user.id,
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=payload.wager_amount,
        win_amount=payload.win_amount,
        multiplier=payload.multiplier,
        metadata=payload.metadata,
    )
    db.commit()
    return GameWinningsToWalletResponse(**result)
