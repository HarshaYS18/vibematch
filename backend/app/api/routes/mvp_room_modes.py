from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.mvp_feature import MvpFeatureCreate, MvpFeatureResponse
from app.services.mvp_feature_service import create_feature_item

router = APIRouter(prefix="/mvp/room-modes", tags=["MVP Room Modes"])


@router.post("/watch-party/session", response_model=MvpFeatureResponse)
def create_watch_party_session(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("host_user_id", current_user.id)
    payload.setdefault("sync_state", "created")
    normalized = data.model_copy(update={"item_type": "watch_party_session", "status": "active", "payload": payload})
    return create_feature_item(db, feature="watch_party", owner_user_id=current_user.id, data=normalized)


@router.post("/watch-party/sync-event", response_model=MvpFeatureResponse)
def create_watch_party_sync_event(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("actor_user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": "sync_event", "payload": payload})
    return create_feature_item(db, feature="watch_party", owner_user_id=current_user.id, data=normalized)


@router.post("/cricket/session", response_model=MvpFeatureResponse)
def create_cricket_session(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("created_by_user_id", current_user.id)
    payload.setdefault("score", {"team_a": 0, "team_b": 0})
    payload.setdefault("innings", 1)
    normalized = data.model_copy(update={"item_type": "cricket_session", "status": "active", "payload": payload})
    return create_feature_item(db, feature="cricket_mode", owner_user_id=current_user.id, data=normalized)


@router.post("/cricket/score-event", response_model=MvpFeatureResponse)
def create_cricket_score_event(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("actor_user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": "score_event", "payload": payload})
    return create_feature_item(db, feature="cricket_mode", owner_user_id=current_user.id, data=normalized)
