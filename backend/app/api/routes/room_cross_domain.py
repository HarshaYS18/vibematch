from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.room_theme import RoomThemePurchaseRequest, RoomThemeResponse
from app.services import economy_service_client, room_control_service_client
from app.services.rooms.room_contribution_service import room_contribution_rankings


router = APIRouter(prefix="/rooms", tags=["Room Cross-domain"])


def _service_error(exc: Exception) -> HTTPException:
    if isinstance(exc, room_control_service_client.RoomControlServiceError):
        return HTTPException(status_code=exc.status_code, detail=exc.detail)
    return HTTPException(status_code=503, detail="Room Control service unavailable")


def _economy_error(exc: Exception) -> HTTPException:
    if isinstance(exc, economy_service_client.EconomyServiceError):
        return HTTPException(status_code=exc.status_code, detail=exc.detail)
    return HTTPException(status_code=503, detail="Economy service unavailable")


def _debit_theme_once(
    *,
    user: User,
    theme_id: str,
    theme_name: str,
    price: int,
) -> None:
    if price <= 0:
        return
    business_reference = f"room-theme-purchase:{user.id}:{theme_id}"
    try:
        economy_service_client.debit_wallet(
            user_id=user.id,
            amount=price,
            source_type="ROOM_THEME_PURCHASE",
            source_id=theme_id,
            reason=f"Purchased room background {theme_name}",
            actor_user_id=user.id,
            business_reference=business_reference,
            operation="room_theme.purchase",
        )
    except (
        economy_service_client.EconomyServiceUnavailable,
        economy_service_client.EconomyServiceError,
    ) as exc:
        raise _economy_error(exc) from exc


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
        # Retry is safe: Economy reuses the stable room-theme purchase business
        # reference, while Room Control grants inventory idempotently.
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
