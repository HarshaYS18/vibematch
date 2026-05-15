from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.store import (
    InventoryItemResponse,
    InventoryResponse,
    StoreCatalogResponse,
    StoreEquipRequest,
    StoreItemResponse,
    StorePurchaseRequest,
)
from app.services import store_service

router = APIRouter(prefix="/store", tags=["Store"])


@router.get("/catalog", response_model=StoreCatalogResponse)
def get_store_catalog(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return store_service.catalog(db, current_user)


@router.post("/purchase", response_model=StoreItemResponse)
def purchase_store_item(
    payload: StorePurchaseRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return store_service.purchase(db, current_user, payload.item_id)


@router.get("/inventory", response_model=InventoryResponse)
def get_user_inventory(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return store_service.inventory(db, current_user)


@router.post("/inventory/equip", response_model=InventoryItemResponse)
def equip_inventory_item(
    payload: StoreEquipRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return store_service.equip(db, current_user, payload.item_id, payload.equipped)
