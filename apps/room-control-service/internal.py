from __future__ import annotations

import hmac

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.room import Room
from app.services.rooms.room_theme_service import (
    grant_room_theme_inventory,
    room_theme_purchase_quote,
)


router = APIRouter(prefix="/internal/room-control", tags=["Room Control Internal"])


class ThemeGrantRequest(BaseModel):
    user_id: int
    source: str = "purchase"


def require_internal_token(
    x_funkey_internal_token: str | None = Header(default=None),
) -> None:
    expected = settings.ROOM_CONTROL_INTERNAL_TOKEN.strip()
    provided = (x_funkey_internal_token or "").strip()
    if not expected or not hmac.compare_digest(provided, expected):
        raise HTTPException(status_code=403, detail="Internal Room Control access denied")


@router.get(
    "/rooms/{room_public_id}",
    dependencies=[Depends(require_internal_token)],
)
def resolve_room(room_public_id: str, db: Session = Depends(get_db)):
    room = (
        db.query(Room)
        .filter(
            Room.room_public_id == room_public_id,
            Room.is_active.is_(True),
        )
        .first()
    )
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return {
        "database_room_id": int(room.id),
        "room_public_id": room.room_public_id,
        "name": room.name,
        "is_active": bool(room.is_active),
    }


@router.get(
    "/themes/{theme_id}/quote",
    dependencies=[Depends(require_internal_token)],
)
def theme_quote(
    theme_id: str,
    user_id: int = Query(..., ge=1),
    db: Session = Depends(get_db),
):
    return room_theme_purchase_quote(db, user_id=user_id, theme_id=theme_id)


@router.post(
    "/themes/{theme_id}/grant",
    dependencies=[Depends(require_internal_token)],
)
def grant_theme(
    theme_id: str,
    payload: ThemeGrantRequest,
    db: Session = Depends(get_db),
):
    return grant_room_theme_inventory(
        db,
        user_id=payload.user_id,
        theme_id=theme_id,
        source=payload.source,
    )
