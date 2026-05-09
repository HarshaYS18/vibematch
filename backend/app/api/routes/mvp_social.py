from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.mvp_feature import MvpFeatureCreate, MvpFeatureResponse
from app.services.mvp_feature_service import create_feature_item

router = APIRouter(prefix="/mvp/social", tags=["MVP Social"])


@router.post("/vibes/post", response_model=MvpFeatureResponse)
def create_vibe_post(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("author_user_id", current_user.id)
    payload.setdefault("like_count", 0)
    payload.setdefault("comment_count", 0)
    payload.setdefault("share_count", 0)
    normalized = data.model_copy(update={"item_type": data.item_type or "post", "payload": payload})
    return create_feature_item(db, feature="vibes", owner_user_id=current_user.id, data=normalized)


@router.post("/vibes/comment", response_model=MvpFeatureResponse)
def create_vibe_comment(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("author_user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": "comment", "payload": payload})
    return create_feature_item(db, feature="vibes", owner_user_id=current_user.id, data=normalized)


@router.post("/relationships/request", response_model=MvpFeatureResponse)
def create_relationship_request(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("requester_user_id", current_user.id)
    payload.setdefault("workflow", "pending_acceptance")
    normalized = data.model_copy(update={"item_type": data.item_type or "relationship_request", "status": "pending", "payload": payload})
    return create_feature_item(db, feature="relationships", owner_user_id=current_user.id, data=normalized)


@router.post("/family/create", response_model=MvpFeatureResponse)
def create_family(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("owner_user_id", current_user.id)
    payload.setdefault("member_count", 1)
    payload.setdefault("family_level", 1)
    normalized = data.model_copy(update={"item_type": "family", "payload": payload})
    return create_feature_item(db, feature="family", owner_user_id=current_user.id, data=normalized)


@router.post("/family/join-request", response_model=MvpFeatureResponse)
def create_family_join_request(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("requester_user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": "join_request", "status": "pending", "payload": payload})
    return create_feature_item(db, feature="family", owner_user_id=current_user.id, data=normalized)
