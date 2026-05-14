from typing import Any

from fastapi import APIRouter, Body, Depends
from sqlalchemy.orm import Session

from app.api.routes.super_owner import require_super_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.game_props import JungleHuntPropsResponse
from app.services import jungle_hunt_props_runtime_service
from app.services.audit_log_service import create_admin_log

router = APIRouter(prefix="/super-owner/game-props", tags=["Super Owner Game Props"])


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
