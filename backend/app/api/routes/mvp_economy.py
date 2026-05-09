from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.mvp_feature import MvpFeatureCreate, MvpFeatureResponse
from app.services.mvp_feature_service import create_feature_item

router = APIRouter(prefix="/mvp/economy", tags=["MVP Economy"])


@router.post("/wallet/recharge", response_model=MvpFeatureResponse)
def create_recharge(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("transaction_kind", "recharge")
    payload.setdefault("source", "mvp_backend")
    normalized = data.model_copy(update={"item_type": "recharge", "currency": data.currency or "coins", "payload": payload})
    return create_feature_item(db, feature="wallet", owner_user_id=current_user.id, data=normalized)


@router.post("/wallet/transaction", response_model=MvpFeatureResponse)
def create_wallet_transaction(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("user_id", current_user.id)
    normalized = data.model_copy(update={"item_type": data.item_type or "transaction", "currency": data.currency or "coins", "payload": payload})
    return create_feature_item(db, feature="wallet", owner_user_id=current_user.id, data=normalized)


@router.post("/gifts/send", response_model=MvpFeatureResponse)
def send_gift(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("sender_user_id", current_user.id)
    payload.setdefault("send_state", "sent")
    normalized = data.model_copy(update={"item_type": data.item_type or "gift_send", "currency": data.currency or "coins", "payload": payload})
    return create_feature_item(db, feature="gifts", owner_user_id=current_user.id, data=normalized)


@router.post("/gifts/catalog-item", response_model=MvpFeatureResponse)
def create_gift_catalog_item(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    normalized = data.model_copy(update={"item_type": data.item_type or "gift_catalog_item", "currency": data.currency or "coins"})
    return create_feature_item(db, feature="gifts", owner_user_id=current_user.id, data=normalized)


@router.post("/store/item", response_model=MvpFeatureResponse)
def create_store_item(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    normalized = data.model_copy(update={"item_type": data.item_type or "store_item", "currency": data.currency or "coins"})
    return create_feature_item(db, feature="store", owner_user_id=current_user.id, data=normalized)


@router.post("/store/inventory", response_model=MvpFeatureResponse)
def create_inventory_item(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("user_id", current_user.id)
    payload.setdefault("equipped", False)
    normalized = data.model_copy(update={"item_type": data.item_type or "inventory_item", "payload": payload})
    return create_feature_item(db, feature="store", owner_user_id=current_user.id, data=normalized)


@router.post("/vip/state", response_model=MvpFeatureResponse)
def create_vip_state(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("user_id", current_user.id)
    payload.setdefault("source", "recharge_based")
    normalized = data.model_copy(update={"item_type": data.item_type or "vip_state", "payload": payload})
    return create_feature_item(db, feature="vip", owner_user_id=current_user.id, data=normalized)


@router.post("/earnings/payout-request", response_model=MvpFeatureResponse)
def create_payout_request(
    data: MvpFeatureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = dict(data.payload)
    payload.setdefault("creator_user_id", current_user.id)
    payload.setdefault("review_status", "pending")
    normalized = data.model_copy(update={"item_type": "payout_request", "status": "pending", "currency": data.currency or "coins", "payload": payload})
    return create_feature_item(db, feature="earnings", owner_user_id=current_user.id, data=normalized)
