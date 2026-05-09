from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.mvp_feature import MvpFeatureState
from app.schemas.mvp_feature import MvpFeatureCreate, MvpFeatureUpdate


def _make_public_id(feature: str) -> str:
    clean = feature.lower().replace("_", "-")[:24]
    return f"{clean}-{uuid4().hex[:12]}"


def list_feature_items(
    db: Session,
    *,
    feature: str,
    owner_user_id: int | None = None,
    room_public_id: str | None = None,
    status: str | None = None,
    active_only: bool = True,
    limit: int = 100,
) -> list[MvpFeatureState]:
    query = db.query(MvpFeatureState).filter(MvpFeatureState.feature == feature)

    if owner_user_id is not None:
        query = query.filter(MvpFeatureState.owner_user_id == owner_user_id)
    if room_public_id is not None:
        query = query.filter(MvpFeatureState.room_public_id == room_public_id)
    if status is not None:
        query = query.filter(MvpFeatureState.status == status)
    if active_only:
        query = query.filter(MvpFeatureState.is_active.is_(True))

    return query.order_by(MvpFeatureState.updated_at.desc()).limit(limit).all()


def create_feature_item(
    db: Session,
    *,
    feature: str,
    owner_user_id: int | None,
    data: MvpFeatureCreate,
) -> MvpFeatureState:
    item = MvpFeatureState(
        public_id=_make_public_id(feature),
        feature=feature,
        item_type=data.item_type,
        owner_user_id=owner_user_id,
        target_user_id=data.target_user_id,
        room_public_id=data.room_public_id,
        title=data.title,
        description=data.description,
        status=data.status,
        amount=data.amount,
        currency=data.currency,
        payload=data.payload,
        is_active=True,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def get_feature_item(db: Session, *, feature: str, public_id: str) -> MvpFeatureState | None:
    return (
        db.query(MvpFeatureState)
        .filter(MvpFeatureState.feature == feature, MvpFeatureState.public_id == public_id)
        .first()
    )


def update_feature_item(
    db: Session,
    *,
    feature: str,
    public_id: str,
    data: MvpFeatureUpdate,
) -> MvpFeatureState | None:
    item = get_feature_item(db, feature=feature, public_id=public_id)
    if not item:
        return None

    changes = data.model_dump(exclude_unset=True)
    for key, value in changes.items():
        setattr(item, key, value)

    db.commit()
    db.refresh(item)
    return item


def deactivate_feature_item(db: Session, *, feature: str, public_id: str) -> MvpFeatureState | None:
    item = get_feature_item(db, feature=feature, public_id=public_id)
    if not item:
        return None
    item.is_active = False
    item.status = "inactive"
    db.commit()
    db.refresh(item)
    return item
