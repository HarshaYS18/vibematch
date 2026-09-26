from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException

from app.api.routes.users import get_current_user
from app.models.user import User
from app.schemas.game_settlements import (
    GameSettleRequest,
    GameSettleResponse,
    GameWagerRequest,
    GameWagerResponse,
    GameWinningsToWalletRequest,
    GameWinningsToWalletResponse,
)
from app.services import economy_service_client

router = APIRouter(prefix="/games", tags=["Game Settlements"])


def _request_id(value: str | None) -> str:
    normalized = (value or "").strip()
    if not normalized:
        return str(uuid4())
    if len(normalized) > 120:
        raise HTTPException(status_code=400, detail="Idempotency-Key is too long")
    return normalized


def _map_economy_error(exc: Exception) -> HTTPException:
    if isinstance(exc, economy_service_client.EconomyServiceError):
        return HTTPException(status_code=exc.status_code, detail=exc.detail)
    return HTTPException(status_code=503, detail=str(exc))


def _settle_via_economy(
    *,
    current_user: User,
    game_id: str,
    round_id: str | None,
    wager_amount: int,
    win_amount: int,
    multiplier: int,
    metadata: dict,
    request_id: str,
    operation: str,
) -> dict:
    try:
        return economy_service_client.game_settle(
            user_id=current_user.id,
            game_id=game_id,
            round_id=round_id,
            wager_amount=wager_amount,
            win_amount=win_amount,
            multiplier=multiplier,
            business_reference=f"{operation}:{current_user.id}:{request_id}",
            metadata=metadata,
        )
    except (
        economy_service_client.EconomyServiceUnavailable,
        economy_service_client.EconomyServiceError,
    ) as exc:
        raise _map_economy_error(exc) from exc


@router.post("/wager", response_model=GameWagerResponse)
def create_game_wager(
    payload: GameWagerRequest,
    current_user: User = Depends(get_current_user),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    request_id = _request_id(idempotency_key)
    try:
        result = economy_service_client.game_wager(
            user_id=current_user.id,
            game_id=payload.game_id,
            round_id=payload.round_id,
            wager_amount=payload.wager_amount,
            business_reference=f"legacy-game-wager:{current_user.id}:{request_id}",
            metadata=payload.metadata,
        )
    except (
        economy_service_client.EconomyServiceUnavailable,
        economy_service_client.EconomyServiceError,
    ) as exc:
        raise _map_economy_error(exc) from exc

    return GameWagerResponse(
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=int(result.get("wager_amount") or payload.wager_amount),
        wallet_coin_balance=int(result.get("wallet_coin_balance") or 0),
        reference_id=payload.round_id or request_id,
        house_reservation=result.get("house_reservation") or {},
        rule="Economy service is the sole game wager financial authority.",
    )


@router.post("/settle", response_model=GameSettleResponse)
def settle_game_round(
    payload: GameSettleRequest,
    current_user: User = Depends(get_current_user),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    result = _settle_via_economy(
        current_user=current_user,
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=payload.wager_amount,
        win_amount=payload.win_amount,
        multiplier=payload.multiplier,
        metadata=payload.metadata,
        request_id=_request_id(idempotency_key),
        operation="legacy-game-settle",
    )
    actual_win = int(result.get("win_amount") or 0)
    wager = int(result.get("wager_amount") or payload.wager_amount)
    risk = result.get("risk") if isinstance(result.get("risk"), dict) else {}
    return GameSettleResponse(
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=wager,
        win_amount=actual_win,
        loss_amount=wager if actual_win <= 0 else max(wager - actual_win, 0),
        net_amount=int(result.get("net_amount") or (actual_win - wager)),
        multiplier=payload.multiplier,
        wallet_coin_balance=int(result.get("wallet_coin_balance") or 0),
        house_profit_or_loss=int(result.get("house_profit_or_loss") or 0),
        risk_score=int(risk.get("suspicious_pattern_score") or 0),
        stats={},
        rule="Economy service is the sole final game settlement authority.",
    )


@router.post(
    "/settle-winnings-to-wallet",
    response_model=GameWinningsToWalletResponse,
)
def settle_game_winnings_to_wallet(
    payload: GameWinningsToWalletRequest,
    current_user: User = Depends(get_current_user),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    result = _settle_via_economy(
        current_user=current_user,
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=payload.wager_amount,
        win_amount=payload.win_amount,
        multiplier=payload.multiplier,
        metadata=payload.metadata,
        request_id=_request_id(idempotency_key),
        operation="legacy-game-winnings",
    )
    actual_win = int(result.get("win_amount") or 0)
    wager = int(result.get("wager_amount") or payload.wager_amount)
    risk = result.get("risk") if isinstance(result.get("risk"), dict) else {}
    return GameWinningsToWalletResponse(
        game_id=payload.game_id,
        round_id=payload.round_id,
        wager_amount=wager,
        win_amount=actual_win,
        loss_amount=wager if actual_win <= 0 else max(wager - actual_win, 0),
        net_amount=int(result.get("net_amount") or (actual_win - wager)),
        multiplier=payload.multiplier,
        wallet_coin_balance=int(result.get("wallet_coin_balance") or 0),
        house_profit_or_loss=int(result.get("house_profit_or_loss") or 0),
        risk_score=int(risk.get("suspicious_pattern_score") or 0),
        rule="Economy service is the sole final game settlement authority.",
    )
