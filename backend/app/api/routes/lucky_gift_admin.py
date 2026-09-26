from __future__ import annotations

from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.game_pools import GamePoolResponse
from app.schemas.lucky_gifts_admin import (
    LuckyGiftModerationResponse,
    LuckyGiftModerationTransaction,
    LuckyGiftPoolAdjustRequest,
    LuckyGiftPoolPairResponse,
    LuckyGiftPoolSettingsRequest,
    LuckyGiftPoolTransferRequest,
    LuckyGiftPropsResponse,
)
from app.services import economy_service_client
from app.services.audit_log_service import create_admin_log

router = APIRouter(prefix="/admin/economy/lucky-gifts", tags=["Super Owner Lucky Gifts"])


@router.get("/props", response_model=LuckyGiftPropsResponse)
def get_lucky_gift_props(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    try:
        result = economy_service_client.get_lucky_gift_admin_props()
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return LuckyGiftPropsResponse(**result)


@router.post("/props", response_model=LuckyGiftPropsResponse)
def update_lucky_gift_props(payload: dict[str, Any] = Body(...), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    request_id = str(payload.get("request_id") or uuid4()).strip()
    props_payload = {key: value for key, value in payload.items() if key != "request_id"}
    try:
        result = economy_service_client.update_lucky_gift_props(
            request_id=request_id,
            actor_user_id=current_user.id,
            props=props_payload,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_PROPS_UPDATED",
        resource_type="lucky_gift_props",
        resource_id="lucky_gifts",
        reason=str(props_payload.get("reason") or "Super Owner lucky gift props update"),
        metadata_json={
            "testing_mode_enabled": result["testing_mode_enabled"],
            "whale_single_spend": result["whale_single_spend"],
            "whale_daily_spend": result["whale_daily_spend"],
            "payout_pool_safe_ratio_basis_points": result["payout_pool_safe_ratio_basis_points"],
            "economy_transaction_id": result.get("transaction_id"),
        },
    )
    return LuckyGiftPropsResponse(**result)


@router.get("/moderation", response_model=LuckyGiftModerationResponse)
def get_lucky_gift_moderation(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    try:
        result = economy_service_client.get_lucky_gift_admin_moderation()
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return LuckyGiftModerationResponse(**result)


@router.get("/house-pool", response_model=LuckyGiftPoolPairResponse)
def get_lucky_gift_house_pool(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    try:
        result = economy_service_client.get_lucky_gift_admin_house_pool()
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return LuckyGiftPoolPairResponse(**result)


@router.get("/house-pool/list", response_model=list[GamePoolResponse])
def list_lucky_gift_house_pools(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    try:
        result = economy_service_client.list_lucky_gift_admin_house_pools()
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return [GamePoolResponse(**item) for item in result.get("pools", [])]


@router.post("/house-pool/adjust", response_model=GamePoolResponse)
def adjust_lucky_gift_house_pool(payload: LuckyGiftPoolAdjustRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.adjust_lucky_gift_pool(
            request_id=request_id,
            actor_user_id=current_user.id,
            game_key=payload.game_key,
            pool_type=payload.pool_type,
            direction=payload.direction,
            amount=payload.amount,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_ADJUSTED",
        resource_type="lucky_gift_house_pool",
        resource_id=str(result["id"]),
        reason=payload.reason,
        metadata_json={
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
            "direction": payload.direction,
            "amount": payload.amount,
            "economy_transaction_id": result.get("transaction_id"),
        },
    )
    return GamePoolResponse(**result)


@router.post("/house-pool/allocate", response_model=LuckyGiftPoolPairResponse)
def allocate_lucky_gift_house_pool(payload: LuckyGiftPoolTransferRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.allocate_lucky_gift_pool(
            request_id=request_id,
            actor_user_id=current_user.id,
            amount=payload.amount,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_ALLOCATED",
        resource_type="lucky_gift_house_pool",
        reason=payload.reason,
        metadata_json={
            "game_key": "lucky_gifts",
            "amount": payload.amount,
            "direction": "MAIN_TO_LUCKY",
            "economy_transaction_id": result.get("transaction_id"),
        },
    )
    return LuckyGiftPoolPairResponse(**result)


@router.post("/house-pool/withdraw", response_model=LuckyGiftPoolPairResponse)
def withdraw_lucky_gift_house_pool(payload: LuckyGiftPoolTransferRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.withdraw_lucky_gift_pool(
            request_id=request_id,
            actor_user_id=current_user.id,
            amount=payload.amount,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_WITHDRAWN",
        resource_type="lucky_gift_house_pool",
        reason=payload.reason,
        metadata_json={
            "game_key": "lucky_gifts",
            "amount": payload.amount,
            "direction": "LUCKY_TO_MAIN",
            "economy_transaction_id": result.get("transaction_id"),
        },
    )
    return LuckyGiftPoolPairResponse(**result)


@router.post("/house-pool/settings", response_model=GamePoolResponse)
def update_lucky_gift_house_pool_settings(payload: LuckyGiftPoolSettingsRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.update_lucky_gift_pool_settings(
            request_id=request_id,
            actor_user_id=current_user.id,
            game_key=payload.game_key,
            pool_type=payload.pool_type,
            status=payload.status,
            daily_payout_cap=payload.daily_payout_cap,
            daily_loss_limit=payload.daily_loss_limit,
            max_single_payout=payload.max_single_payout,
            rtp_target_basis_points=payload.rtp_target_basis_points,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_POOL_SETTINGS_UPDATED",
        resource_type="lucky_gift_house_pool",
        resource_id=str(result["id"]),
        reason=payload.reason,
        metadata_json={
            "game_key": payload.game_key,
            "pool_type": payload.pool_type,
            "status": payload.status,
            "daily_payout_cap": payload.daily_payout_cap,
            "daily_loss_limit": payload.daily_loss_limit,
            "max_single_payout": payload.max_single_payout,
            "rtp_target_basis_points": payload.rtp_target_basis_points,
            "economy_transaction_id": result.get("transaction_id"),
        },
    )
    return GamePoolResponse(**result)

