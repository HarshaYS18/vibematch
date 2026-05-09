from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.mvp_feature import MvpActionResponse, MvpFeatureCreate, MvpFeatureResponse, MvpFeatureUpdate
from app.services.mvp_feature_service import (
    create_feature_item,
    deactivate_feature_item,
    get_feature_item,
    list_feature_items,
    update_feature_item,
)

router = APIRouter(prefix="/mvp", tags=["MVP Core"])

FEATURES = {
    "wallet": "Wallet and transaction state",
    "gifts": "Gift catalog and send state",
    "store": "Store and inventory state",
    "vip": "VIP and SVIP state",
    "vibes": "Vibes post state",
    "relationships": "Relationship state",
    "family": "Family and family event state",
    "agency": "Agency and host state",
    "events": "App event state",
    "rankings": "Ranking state",
    "watch_party": "Watch party state",
    "cricket_mode": "Cricket room mode state",
    "assets": "Dynamic asset review state",
    "reports": "Report workflow state",
    "earnings": "Creator earnings state",
    "control_center": "Official panel action state",
}


@router.get("/features")
def list_mvp_features():
    return {"features": FEATURES}


@router.get("/{feature}", response_model=list[MvpFeatureResponse])
def list_items(
    feature: str,
    owner_user_id: int | None = None,
    room_public_id: str | None = None,
    status: str | None = None,
    active_only: bool = True,
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _validate_feature(feature)
    return list_feature_items(
        db,
        feature=feature,
        owner_user_id=owner_user_id,
        room_public_id=room_public_id,
        status=status,
        active_only=active_only,
        limit=limit,
    )


@router.post("/{feature}", response_model=MvpFeatureResponse)
def create_item(
    feature: str,
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _validate_feature(feature)
    return create_feature_item(db, feature=feature, owner_user_id=current_user.id, data=data)


@router.get("/{feature}/{public_id}", response_model=MvpFeatureResponse)
def get_item(
    feature: str,
    public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _validate_feature(feature)
    item = get_feature_item(db, feature=feature, public_id=public_id)
    if not item:
        raise HTTPException(status_code=404, detail="MVP item not found")
    return item


@router.patch("/{feature}/{public_id}", response_model=MvpFeatureResponse)
def update_item(
    feature: str,
    public_id: str,
    data: MvpFeatureUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _validate_feature(feature)
    item = update_feature_item(db, feature=feature, public_id=public_id, data=data)
    if not item:
        raise HTTPException(status_code=404, detail="MVP item not found")
    return item


@router.delete("/{feature}/{public_id}", response_model=MvpActionResponse)
def delete_item(
    feature: str,
    public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _validate_feature(feature)
    item = deactivate_feature_item(db, feature=feature, public_id=public_id)
    if not item:
        raise HTTPException(status_code=404, detail="MVP item not found")
    return MvpActionResponse(message="MVP item deactivated", item=item)


def _validate_feature(feature: str) -> None:
    if feature not in FEATURES:
        raise HTTPException(status_code=404, detail=f"Unknown MVP feature '{feature}'")
