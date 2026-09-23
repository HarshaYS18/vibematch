"""Authoritative verification for the strangler Go realtime gateway.

The gateway transports events only. Room membership and moderation decisions
remain in this control plane until a separately tested domain migration.
"""

from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.core.security import decode_access_token
from app.database import get_db
from app.models.role import RoleName
from app.models.room import Room
from app.models.user import User
from app.services import role_service
from app.services.ban_service import is_device_banned
from app.services.permissions.media_room_permission_service import evaluate_media_room_permission


router = APIRouter(prefix="/realtime", tags=["Realtime Gateway Auth"])

_REALTIME_STAFF_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
    RoleName.SUPERADMIN,
    RoleName.ADMIN,
    RoleName.MONITOR,
    RoleName.CS,
}


class RealtimeVerifyRequest(BaseModel):
    requested_action: Literal["connect", "subscribe"]
    room_public_id: str | None = Field(default=None, min_length=1, max_length=32)


class RealtimeVerifyResponse(BaseModel):
    allowed: bool
    user_id: int
    is_staff: bool = False


@router.post("/verify", response_model=RealtimeVerifyResponse)
def verify_realtime_gateway(
    payload: RealtimeVerifyRequest,
    authorization: str | None = Header(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Recheck token/session/device state and requested room subscription."""
    token = (authorization or "").removeprefix("Bearer ").strip()
    claims = decode_access_token(token) or {}
    device_id = str(claims.get("device_id") or "").strip()
    if device_id and is_device_banned(db, device_id):
        raise HTTPException(status_code=403, detail="Device is banned")

    if payload.requested_action == "subscribe":
        if not payload.room_public_id:
            raise HTTPException(status_code=422, detail="room_public_id is required")
        room = db.query(Room).filter(Room.room_public_id == payload.room_public_id).first()
        if room is None or not room.is_active:
            raise HTTPException(status_code=404, detail="Room unavailable")
        decision = evaluate_media_room_permission(
            db=db,
            user=current_user,
            room=room,
            action="join_room",
            device_id=device_id,
            has_active_room_connection=False,
        )
        if not decision.allowed:
            raise HTTPException(
                status_code=403,
                detail=decision.reason or "Room access denied",
            )

    return RealtimeVerifyResponse(
        allowed=True,
        user_id=current_user.id,
        is_staff=role_service.get_primary_role(current_user) in _REALTIME_STAFF_ROLES,
    )
