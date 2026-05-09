from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.mvp_feature import MvpFeatureCreate, MvpFeatureResponse
from app.services.mvp_feature_service import create_feature_item

router = APIRouter(prefix="/mvp/ops", tags=["MVP Operations"])


@router.post("/assets/custom-room-background", response_model=MvpFeatureResponse)
def submit_custom_room_background(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("submitted_by_user_id", current_user.id)
    payload.setdefault("review_status", "pending")
    normalized = data.model_copy(update={"item_type": "custom_room_background", "status": "pending", "payload": payload})
    return create_feature_item(db, feature="assets", owner_user_id=current_user.id, data=normalized)


@router.post("/events/app-event", response_model=MvpFeatureResponse)
def create_app_event(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("created_by_user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": data.item_type or "app_event", "payload": payload})
    return create_feature_item(db, feature="events", owner_user_id=current_user.id, data=normalized)


@router.post("/rankings/snapshot", response_model=MvpFeatureResponse)
def create_ranking_snapshot(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("generated_by", "mvp_backend")
    normalized = data.model_copy(update={"item_type": data.item_type or "ranking_snapshot", "payload": payload})
    return create_feature_item(db, feature="rankings", owner_user_id=current_user.id, data=normalized)


@router.post("/reports/create", response_model=MvpFeatureResponse)
def create_report(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("submitted_by_user_id", current_user.id)
    payload.setdefault("workflow_status", "submitted")
    normalized = data.model_copy(update={"item_type": data.item_type or "user_report", "status": "submitted", "payload": payload})
    return create_feature_item(db, feature="reports", owner_user_id=current_user.id, data=normalized)


@router.post("/reports/escalate", response_model=MvpFeatureResponse)
def escalate_report(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("submitted_by_user_id", current_user.id)
    payload.setdefault("destination_team", "monitor")
    payload.setdefault("workflow_status", "escalated")
    normalized = data.model_copy(update={"item_type": "review_escalation", "status": "escalated", "payload": payload})
    return create_feature_item(db, feature="reports", owner_user_id=current_user.id, data=normalized)


@router.post("/agency/request", response_model=MvpFeatureResponse)
def create_agency_request(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("submitted_by_user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": data.item_type or "agency_request", "status": "pending", "payload": payload})
    return create_feature_item(db, feature="agency", owner_user_id=current_user.id, data=normalized)


@router.post("/control-center/action", response_model=MvpFeatureResponse)
def create_control_center_action(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("actor_user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": data.item_type or "control_action", "payload": payload})
    return create_feature_item(db, feature="control_center", owner_user_id=current_user.id, data=normalized)
