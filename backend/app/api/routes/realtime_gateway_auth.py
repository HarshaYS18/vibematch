"""Authoritative verification for the strangler Go realtime gateway.

The gateway transports events only. Room membership and moderation decisions
remain in this control plane until a separately tested domain migration.
"""

import asyncio
from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.core.security import decode_access_token
from app.database import get_db
from app.models.role import RoleName
from app.models.user import User
from app.services import realtime_capability_service, role_service, room_control_service_client
from app.services.ban_service import is_device_banned


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


class RealtimeCapabilityRequest(BaseModel):
    room_public_id: str | None = Field(default=None, min_length=1, max_length=32)


class RealtimeCapabilityResponse(BaseModel):
    token: str
    expires_at: int
    session_id: str
    token_version: int
    scopes: list[str]
    room_public_id: str | None = None
    permissions: list[str] = Field(default_factory=list)
    membership_version: int | None = None


class RealtimeCommandRequest(BaseModel):
    type: str = Field(min_length=1, max_length=80)
    room_public_id: str | None = Field(default=None, min_length=1, max_length=32)
    conversation_id: str | None = Field(default=None, min_length=1, max_length=128)
    activity: str | None = Field(default=None, max_length=32)
    command_id: str | None = Field(default=None, max_length=128)
    payload: dict = Field(default_factory=dict)


class RealtimeCommandResponse(BaseModel):
    accepted: bool = True
    command_id: str | None = None
    scope: str
    room_public_id: str | None = None
    conversation_id: str | None = None
    state_version: int | None = None
    event_sequence: int | None = None
    result: str | None = None


@router.get("/capability-key")
def get_realtime_capability_key():
    """Expose only the public Ed25519 verification key."""

    return realtime_capability_service.public_jwk()


@router.post("/capability", response_model=RealtimeCapabilityResponse)
def issue_realtime_capability(
    payload: RealtimeCapabilityRequest,
    authorization: str | None = Header(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mint one short-lived connect or room-bound realtime capability."""

    access_token = (authorization or "").removeprefix("Bearer ").strip()
    claims = decode_access_token(access_token) or {}
    device_id = str(claims.get("device_id") or "").strip()
    if device_id and is_device_banned(db, device_id):
        raise HTTPException(status_code=403, detail="Device is banned")

    is_staff = role_service.get_primary_role(current_user) in _REALTIME_STAFF_ROLES
    room_public_id = payload.room_public_id
    permissions: list[str] = []
    membership_version: int | None = None
    scopes = ["realtime:connect"]

    if room_public_id:
        try:
            decision = room_control_service_client.authorize_room_action(
                user_id=current_user.id,
                room_public_id=room_public_id,
                action="join_room",
                device_id=device_id,
                has_active_room_connection=False,
                evaluate_permissions=True,
            )
        except room_control_service_client.RoomControlServiceUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        except room_control_service_client.RoomControlServiceError as exc:
            raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
        if not decision.get("allowed", False):
            raise HTTPException(
                status_code=403,
                detail=str(decision.get("reason") or "Room access denied"),
            )
        scopes = ["room:subscribe"]
        permissions = list(decision.get("permissions") or [])
        membership_version = int(decision.get("membership_version") or 0)

    issued = realtime_capability_service.issue_realtime_capability(
        access_token=access_token,
        user_id=current_user.id,
        device_id=device_id,
        is_staff=is_staff,
        scopes=scopes,
        room_id=room_public_id,
        permissions=permissions,
        membership_version=membership_version,
    )
    return RealtimeCapabilityResponse(
        token=issued.token,
        expires_at=issued.expires_at,
        session_id=issued.session_id,
        token_version=realtime_capability_service.settings.REALTIME_CAPABILITY_TOKEN_VERSION,
        scopes=scopes,
        room_public_id=room_public_id,
        permissions=permissions,
        membership_version=membership_version,
    )


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
        try:
            decision = room_control_service_client.authorize_room_action(
                user_id=current_user.id,
                room_public_id=payload.room_public_id,
                action="join_room",
                device_id=device_id,
                has_active_room_connection=False,
                evaluate_permissions=True,
            )
        except room_control_service_client.RoomControlServiceUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        except room_control_service_client.RoomControlServiceError as exc:
            raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
        if not decision.get("allowed", False):
            raise HTTPException(
                status_code=403,
                detail=str(decision.get("reason") or "Room access denied"),
            )

    return RealtimeVerifyResponse(
        allowed=True,
        user_id=current_user.id,
        is_staff=role_service.get_primary_role(current_user) in _REALTIME_STAFF_ROLES,
    )


@router.post("/command", response_model=RealtimeCommandResponse)
async def execute_realtime_command(
    payload: RealtimeCommandRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Execute one allowlisted application command in the authoritative API."""
    room_public_id = str(payload.room_public_id or "").strip()
    if not room_public_id:
        raise HTTPException(status_code=422, detail="room_public_id is required")
    try:
        result = await asyncio.to_thread(
            room_control_service_client.execute_realtime_command,
            user_id=current_user.id,
            command_type=payload.type,
            room_public_id=room_public_id,
            activity=payload.activity,
            payload=payload.payload,
            command_id=payload.command_id,
        )
    except room_control_service_client.RoomControlServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except room_control_service_client.RoomControlServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return RealtimeCommandResponse(
        command_id=payload.command_id,
        **result,
    )
