from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.user import User
from app.schemas.room_theme import RoomThemePurchaseRequest, RoomThemeResponse
from app.services import room_control_service_client
from app.services.rooms.room_contribution_service import room_contribution_rankings


router = APIRouter(prefix="/rooms", tags=["Room Cross-domain"])


def _service_error(exc: Exception) -> HTTPException:
    if isinstance(exc, room_control_service_client.RoomControlServiceError):
        return HTTPException(status_code=exc.status_code, detail=exc.detail)
    return HTTPException(status_code=503, detail="Room Control service unavailable")


def _wallet_for_update(db: Session, user_id: int) -> UserWallet:
    wallet = (
        db.query(UserWallet)
        .filter(UserWallet.user_id == user_id)
        .with_for_update()
        .first()
    )
    if wallet is None:
        wallet = UserWallet(user_id=user_id)
        db.add(wallet)
        db.flush()
    return wallet


def _debit_theme_once(
    db: Session,
    *,
    user: User,
    theme_id: str,
    theme_name: str,
    price: int,
) -> None:
    if price <= 0:
        return

    wallet = _wallet_for_update(db, user.id)
    existing = (
        db.query(WalletLedger.id)
        .filter(
            WalletLedger.user_id == user.id,
            WalletLedger.source_type == "ROOM_THEME_PURCHASE",
            WalletLedger.source_id == theme_id,
        )
        .first()
    )
    if existing is not None:
        return
    if int(wallet.coin_balance or 0) < price:
        raise HTTPException(
            status_code=400,
            detail="Insufficient coins to purchase this room background",
        )

    before = int(wallet.coin_balance or 0)
    wallet.coin_balance = before - price
    wallet.lifetime_coins_spent = int(wallet.lifetime_coins_spent or 0) + price
    db.add(
        WalletLedger(
            user_id=user.id,
            currency_type=EconomyCurrency.COIN.value,
            direction=EconomyDirection.DEBIT.value,
            amount=price,
            before_balance=before,
            after_balance=wallet.coin_balance,
            source_type="ROOM_THEME_PURCHASE",
            source_id=theme_id,
            created_by_user_id=user.id,
            reason=f"Purchased room background {theme_name}",
        )
    )
    db.commit()


@router.post("/themes/purchase", response_model=RoomThemeResponse)
def purchase_room_background_theme(
    payload: RoomThemePurchaseRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        quote = room_control_service_client.room_theme_quote(
            user_id=current_user.id,
            theme_id=payload.theme_id,
        )
    except Exception as exc:
        raise _service_error(exc) from exc

    if not bool(quote.get("is_owned")):
        _debit_theme_once(
            db,
            user=current_user,
            theme_id=str(quote.get("theme_id") or payload.theme_id),
            theme_name=str(quote.get("name") or "Room background"),
            price=int(quote.get("price_coins") or 0),
        )

    try:
        granted = room_control_service_client.grant_room_theme(
            user_id=current_user.id,
            theme_id=str(quote.get("theme_id") or payload.theme_id),
            source=str(quote.get("ownership_type") or "purchase"),
        )
    except Exception as exc:
        # A retry is safe: the wallet debit above is idempotent under the
        # wallet row lock + ledger lookup, while the room inventory grant is
        # idempotent inside Room Control.
        raise _service_error(exc) from exc
    return RoomThemeResponse(**granted)


@router.get("/{room_public_id}/contributions")
def get_room_contribution_rankings(
    room_public_id: str,
    period: str = Query(default="daily"),
    category: str = Query(default="sent"),
    limit: int = Query(default=100, ge=1, le=100),
    db: Session = Depends(get_db),
):
    try:
        room = room_control_service_client.resolve_room(room_public_id)
    except room_control_service_client.RoomControlServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    except room_control_service_client.RoomControlServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    payload = room_contribution_rankings(
        db=db,
        room_public_id=room_public_id,
        resolved_room_id=int(room["database_room_id"]),
        resolved_room_name=str(room.get("name") or room_public_id),
        category=category,
        period=period,
        limit=limit,
    )
    if payload is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return payload
