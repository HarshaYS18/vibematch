from __future__ import annotations

import hmac
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.room import Room
from app.models.user import User
from app.services import realtime_command_service
from app.services.permissions.media_room_permission_service import evaluate_media_room_permission
from app.services.rooms.room_theme_service import (
    grant_room_theme_inventory,
    room_theme_purchase_quote,
)


router = APIRouter(prefix="/internal/room-control", tags=["Room Control Internal"])


class ThemeGrantRequest(BaseModel):
    user_id: int
    source: str = "purchase"


class RoomAuthorizationRequest(BaseModel):
    user_id: int
    room_public_id: str
    action: str = "join_room"
    device_id: str | None = None
    has_active_room_connection: bool = False
    evaluate_permissions: bool = True


class RoomRealtimeCommandRequest(BaseModel):
    user_id: int
    command_type: str
    room_public_id: str
    activity: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)
    command_id: str | None = None


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


@router.post(
    "/authorize",
    dependencies=[Depends(require_internal_token)],
)
def authorize_room_action(
    payload: RoomAuthorizationRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == payload.user_id).first()
    if user is None or not user.is_active or user.is_banned:
        raise HTTPException(status_code=401, detail="Room user is not active")

    room = (
        db.query(Room)
        .filter(Room.room_public_id == payload.room_public_id)
        .first()
    )
    if room is None or not room.is_active:
        raise HTTPException(status_code=404, detail="Room unavailable")

    room_context = {
        "room_public_id": room.room_public_id,
        "room_name": room.name,
        "is_active": bool(room.is_active),
        "is_secret": bool(room.is_secret),
        "is_locked": bool(room.is_locked),
        "is_members_only": bool(room.is_members_only),
        "apply_only_mode_enabled": bool(room.apply_only_mode_enabled),
        "membership_version": int(room.realtime_version or 0),
        "event_sequence": int(room.realtime_event_sequence or 0),
    }
    if not payload.evaluate_permissions:
        return {
            "allowed": True,
            "reason": None,
            "permissions": [],
            "permission_context": {},
            "room": room_context,
            "membership_version": room_context["membership_version"],
        }

    decision = evaluate_media_room_permission(
        db=db,
        user=user,
        room=room,
        action=payload.action,
        device_id=payload.device_id,
        has_active_room_connection=payload.has_active_room_connection,
    )
    return {
        "allowed": bool(decision.allowed),
        "reason": decision.reason,
        "permissions": list(decision.permissions),
        "permission_context": dict(decision.context),
        "room": room_context,
        "membership_version": room_context["membership_version"],
    }


@router.post(
    "/command",
    dependencies=[Depends(require_internal_token)],
)
async def execute_room_command(
    payload: RoomRealtimeCommandRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == payload.user_id).first()
    if user is None or not user.is_active or user.is_banned:
        raise HTTPException(status_code=401, detail="Room user is not active")
    return await realtime_command_service.execute_application_realtime_command(
        db,
        user,
        command_type=payload.command_type,
        room_public_id=payload.room_public_id,
        conversation_id=None,
        activity=payload.activity,
        payload=dict(payload.payload or {}),
        command_id=payload.command_id,
    )
