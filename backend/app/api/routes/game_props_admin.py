from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.game_props import (
    JungleHuntPropsResponse,
    LuckyGiftHousePoolResponse,
    LuckyGiftHousePoolUpdateRequest,
    LuckyGiftPropsResponse,
)
from app.services import economy_service_client, jungle_hunt_props_runtime_service
from app.services.audit_log_service import create_admin_log

router = APIRouter(prefix="/admin/games/props", tags=["Admin Game Props"])

@router.get("/jungle-hunt", response_model=JungleHuntPropsResponse)
def get_jungle_hunt_props(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    return JungleHuntPropsResponse(**jungle_hunt_props_runtime_service.get_props(db))


@router.post("/jungle-hunt", response_model=JungleHuntPropsResponse)
def update_jungle_hunt_props(
    payload: dict[str, Any] = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    result = jungle_hunt_props_runtime_service.update_props(db, current_user, payload)

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_JUNGLE_HUNT_PROPS_UPDATED",
        resource_type="game_props",
        resource_id="jungle_hunt",
        reason=str(payload.get("reason") or "Super Owner Jungle Hunt props update"),
        metadata_json={
            "testing_mode_enabled": result["testing_mode_enabled"],
            "max_round_liability": result["max_round_liability"],
            "max_target_liability": result["max_target_liability"],
            "max_total_bet_per_round": result["max_total_bet_per_round"],
        },
    )

    return JungleHuntPropsResponse(**result)


@router.get("/lucky-gifts", response_model=LuckyGiftPropsResponse)
def get_lucky_gift_props(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    try:
        result = economy_service_client.get_lucky_gift_admin_props()
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return LuckyGiftPropsResponse(**result)


@router.post("/lucky-gifts", response_model=LuckyGiftPropsResponse)
def update_lucky_gift_props(
    payload: dict[str, Any] = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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
        resource_type="game_props",
        resource_id="lucky_gifts",
        reason=str(props_payload.get("reason") or "Super Owner lucky g@router.get("/lucky-gifts/house-pool", response_model=LuckyGiftHousePoolResponse)
def get_lucky_gift_house_pool(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    try:
        result = economy_service_client.get_lucky_gift_control_house_pool()
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return LuckyGiftHousePoolResponse(**result)


@router.post("/lucky-gifts/house-pool", response_model=LuckyGiftHousePoolResponse)
def update_lucky_gift_house_pool(
    payload: LuckyGiftHousePoolUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.update_lucky_gift_control_house_pool(
            request_id=request_id,
            actor_user_id=current_user.id,
            balance=payload.balance,
            reserved_balance=payload.reserved_balance,
            max_payout_per_round=payload.max_payout_per_round,
            daily_house_loss_limit=payload.daily_house_loss_limit,
            rtp_target_basis_points=payload.rtp_target_basis_points,
            status=payload.status,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_LUCKY_GIFT_HOUSE_POOL_UPDATED",
        resource_type="game_pool",
        resource_id=f'{result["game_key"]}:{result["pool_type"]}',
        reason=payload.reason,
        metadata_json={
            key: value
            for key, value in result.items()
            if key != "transaction_id"
        }
        | {"economy_transaction_id": result.get("transaction_id")},
    )

    return LuckyGiftHousePoolResponse(**result)

