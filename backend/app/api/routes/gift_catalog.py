from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.gift_catalog import GiftCatalogCategory, GiftCatalogItem
from app.models.role import RoleName
from app.models.user import User
from app.services import gift_catalog_service, lucky_gift_props_service
from app.services.audit_log_service import create_admin_log
from app.services.role_service import get_primary_role

router = APIRouter(prefix="/gifts", tags=["Gifts"])

DISPLAY_MODES = {"normal", "large_80"}


class LuckyGiftRollRequest(BaseModel):
    gift_id: str = Field(..., min_length=1, max_length=80)
    quantity: int = Field(default=1, gt=0, le=999999)
    house_risk_score: int = Field(default=0, ge=0, le=100)


class AdminReasonRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=500)


class GiftCategoryAdminPayload(AdminReasonRequest):
    key: str = Field(..., min_length=1, max_length=80)
    label: str = Field(..., min_length=1, max_length=120)
    is_enabled: bool = True
    sort_order: int = Field(default=500, ge=0, le=100000)


class GiftCategoryEnabledPayload(AdminReasonRequest):
    is_enabled: bool


class GiftItemAdminPayload(AdminReasonRequest):
    gift_id: str = Field(..., min_length=1, max_length=100)
    name: str = Field(..., min_length=1, max_length=160)
    category_key: str = Field(..., min_length=1, max_length=80)
    gift_type: str = Field(default="normal", min_length=1, max_length=40)
    coin_value: int = Field(..., ge=0, le=100000000)
    min_combo: int = Field(default=1, ge=1, le=999999)
    max_combo: int = Field(default=999, ge=1, le=999999)
    icon_key: str | None = Field(default=None, max_length=120)
    chat_symbol: str | None = Field(default=None, max_length=32)
    asset_path: str | None = None
    video_asset_path: str | None = None
    cdn_asset_path: str | None = None
    cdn_video_path: str | None = None
    animation_type: str = Field(default="image", min_length=1, max_length=40)
    display_mode: str = Field(default="normal", min_length=1, max_length=40)
    is_enabled: bool = True
    show_gift_slide: bool = True
    show_premium_broadcast: bool = False
    show_gift_flight: bool = True
    version: int = Field(default=1, ge=1, le=100000)
    sort_order: int = Field(default=500, ge=0, le=100000)
    max_multiplier: int | None = Field(default=None, ge=1, le=1000)
    metadata_json: dict | None = None

    @model_validator(mode="after")
    def validate_limits_and_display_mode(self):
        if self.max_combo < self.min_combo:
            raise ValueError("max_combo must be greater than or equal to min_combo")
        clean_mode = self.display_mode.strip().lower()
        if clean_mode not in DISPLAY_MODES:
            raise ValueError("display_mode must be normal or large_80")
        self.display_mode = clean_mode
        return self


class GiftItemEnabledPayload(AdminReasonRequest):
    is_enabled: bool


GIFT_CATALOG_ADMIN_ROLES = {RoleName.FOUNDER_OWNER, RoleName.OWNER}


def _clean_key(value: str) -> str:
    return value.strip().lower().replace(" ", "_")


def _clean_display_mode(value: str | None) -> str:
    clean = (value or "normal").strip().lower()
    return clean if clean in DISPLAY_MODES else "normal"


def _require_gift_catalog_admin(current_user: User) -> None:
    if get_primary_role(current_user) not in GIFT_CATALOG_ADMIN_ROLES:
        raise HTTPException(status_code=403, detail="Founder Owner or Owner access required")


def _audit(db: Session, *, actor: User, action: str, resource_id: str, reason: str, metadata: dict | None = None) -> None:
    create_admin_log(db, actor_user_id=actor.id, target_user_id=None, action=action, resource_type="gift_catalog", resource_id=resource_id, reason=reason, metadata_json=metadata or {})


def _category_response(category: GiftCatalogCategory) -> dict:
    return {"key": category.category_key, "label": category.label, "is_enabled": category.is_enabled, "sort_order": category.sort_order, "source": category.source, "created_at": category.created_at, "updated_at": category.updated_at}


def _display_mode_map(db: Session) -> dict[str, str]:
    items = db.query(GiftCatalogItem.gift_id, GiftCatalogItem.display_mode).all()
    return {str(gift_id): _clean_display_mode(display_mode) for gift_id, display_mode in items}


def _apply_display_modes_to_catalog(catalog: dict, db: Session) -> dict:
    modes = _display_mode_map(db)
    for key in ("items", "normal", "lucky", "all"):
        values = catalog.get(key)
        if not isinstance(values, list):
            continue
        for gift in values:
            if isinstance(gift, dict):
                gift["display_mode"] = modes.get(str(gift.get("id") or ""), _clean_display_mode(gift.get("display_mode")))
    return catalog


def _item_response(item: GiftCatalogItem) -> dict:
    gift = gift_catalog_service._with_dynamic_urls(gift_catalog_service._item_to_gift_dict(item))
    gift["display_mode"] = _clean_display_mode(item.display_mode)
    gift["created_at"] = item.created_at
    gift["updated_at"] = item.updated_at
    return gift


@router.get("/catalog")
def get_gift_catalog(db: Session = Depends(get_db)):
    return _apply_display_modes_to_catalog(gift_catalog_service.list_gifts(db), db)


@router.get("/catalog/{gift_id}")
def get_gift_detail(gift_id: str, db: Session = Depends(get_db)):
    gift = gift_catalog_service.find_gift(gift_id, db=db)
    if gift is None:
        raise HTTPException(status_code=404, detail="Gift not found")
    item = db.query(GiftCatalogItem).filter(GiftCatalogItem.gift_id == gift_id).first()
    gift["display_mode"] = _clean_display_mode(item.display_mode if item else gift.get("display_mode"))
    return gift


@router.post("/lucky/roll")
def roll_lucky_gift(payload: LuckyGiftRollRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    gift = gift_catalog_service.find_gift(payload.gift_id, db=db)
    if gift is None:
        raise HTTPException(status_code=404, detail="Gift not found")
    if gift.get("gift_type") != "lucky":
        raise HTTPException(status_code=400, detail="Gift is not a lucky gift")
    try:
        gift_catalog_service.validate_gift_combo(gift, payload.quantity)
        return lucky_gift_props_service.roll_lucky_gift(db, gift_id=payload.gift_id, gift_name=str(gift.get("name") or payload.gift_id.replace("_", " ").title()), base_coin_value=int(gift["coin_value"]), quantity=payload.quantity, house_risk_score=payload.house_risk_score)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/admin/catalog/seed-defaults")
def seed_default_gift_catalog(payload: AdminReasonRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_gift_catalog_admin(current_user)
    result = gift_catalog_service.seed_default_catalog(db)
    _audit(db, actor=current_user, action="GIFT_CATALOG_SEED_DEFAULTS", resource_id="catalog", reason=payload.reason, metadata=result)
    db.commit()
    return {"status": "ok", **result, "catalog": _apply_display_modes_to_catalog(gift_catalog_service.admin_catalog_snapshot(db), db)}


@router.get("/admin/catalog")
def get_admin_gift_catalog(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_gift_catalog_admin(current_user)
    return _apply_display_modes_to_catalog(gift_catalog_service.admin_catalog_snapshot(db), db)


@router.put("/admin/categories/{category_key}")
def upsert_gift_category(category_key: str, payload: GiftCategoryAdminPayload, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_gift_catalog_admin(current_user)
    path_key = _clean_key(category_key)
    body_key = _clean_key(payload.key)
    if path_key != body_key:
        raise HTTPException(status_code=400, detail="Path category key and payload key must match")
    category = db.query(GiftCatalogCategory).filter(GiftCatalogCategory.category_key == path_key).first()
    action = "GIFT_CATEGORY_UPDATED"
    if category is None:
        category = GiftCatalogCategory(category_key=path_key, source="admin_db")
        db.add(category)
        action = "GIFT_CATEGORY_CREATED"
    category.label = payload.label.strip()
    category.is_enabled = payload.is_enabled
    category.sort_order = payload.sort_order
    category.source = "admin_db"
    _audit(db, actor=current_user, action=action, resource_id=path_key, reason=payload.reason, metadata={"category_key": path_key, "label": category.label, "is_enabled": category.is_enabled})
    db.commit()
    db.refresh(category)
    return _category_response(category)


@router.patch("/admin/categories/{category_key}/enabled")
def set_gift_category_enabled(category_key: str, payload: GiftCategoryEnabledPayload, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_gift_catalog_admin(current_user)
    key = _clean_key(category_key)
    category = db.query(GiftCatalogCategory).filter(GiftCatalogCategory.category_key == key).first()
    if category is None:
        raise HTTPException(status_code=404, detail="Gift category not found")
    category.is_enabled = payload.is_enabled
    _audit(db, actor=current_user, action="GIFT_CATEGORY_ENABLED_CHANGED", resource_id=key, reason=payload.reason, metadata={"is_enabled": payload.is_enabled})
    db.commit()
    db.refresh(category)
    return _category_response(category)


@router.put("/admin/items/{gift_id}")
def upsert_gift_item(gift_id: str, payload: GiftItemAdminPayload, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_gift_catalog_admin(current_user)
    path_id = gift_id.strip()
    body_id = payload.gift_id.strip()
    if path_id != body_id:
        raise HTTPException(status_code=400, detail="Path gift_id and payload gift_id must match")
    category_key = _clean_key(payload.category_key)
    category = db.query(GiftCatalogCategory).filter(GiftCatalogCategory.category_key == category_key).first()
    if category is None:
        raise HTTPException(status_code=400, detail="Create the gift category before assigning gifts to it")
    item = db.query(GiftCatalogItem).filter(GiftCatalogItem.gift_id == path_id).first()
    action = "GIFT_ITEM_UPDATED"
    if item is None:
        item = GiftCatalogItem(gift_id=path_id)
        db.add(item)
        action = "GIFT_ITEM_CREATED"
    item.name = payload.name.strip()
    item.category_key = category_key
    item.gift_type = _clean_key(payload.gift_type)
    item.coin_value = payload.coin_value
    item.min_combo = payload.min_combo
    item.max_combo = payload.max_combo
    item.icon_key = payload.icon_key
    item.chat_symbol = payload.chat_symbol
    item.asset_path = payload.asset_path
    item.video_asset_path = payload.video_asset_path
    item.cdn_asset_path = payload.cdn_asset_path
    item.cdn_video_path = payload.cdn_video_path
    item.animation_type = _clean_key(payload.animation_type)
    item.display_mode = _clean_display_mode(payload.display_mode)
    item.is_enabled = payload.is_enabled
    item.show_gift_slide = payload.show_gift_slide
    item.show_premium_broadcast = payload.show_premium_broadcast
    item.show_gift_flight = payload.show_gift_flight
    item.version = payload.version
    item.sort_order = payload.sort_order
    item.max_multiplier = payload.max_multiplier
    item.metadata_json = payload.metadata_json
    _audit(db, actor=current_user, action=action, resource_id=path_id, reason=payload.reason, metadata={"gift_id": path_id, "name": item.name, "category_key": item.category_key, "is_enabled": item.is_enabled, "min_combo": item.min_combo, "max_combo": item.max_combo, "display_mode": item.display_mode})
    db.commit()
    db.refresh(item)
    return _item_response(item)


@router.patch("/admin/items/{gift_id}/enabled")
def set_gift_item_enabled(gift_id: str, payload: GiftItemEnabledPayload, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_gift_catalog_admin(current_user)
    item = db.query(GiftCatalogItem).filter(GiftCatalogItem.gift_id == gift_id.strip()).first()
    if item is None:
        raise HTTPException(status_code=404, detail="Gift item not found")
    item.is_enabled = payload.is_enabled
    _audit(db, actor=current_user, action="GIFT_ITEM_ENABLED_CHANGED", resource_id=gift_id.strip(), reason=payload.reason, metadata={"is_enabled": payload.is_enabled})
    db.commit()
    db.refresh(item)
    return _item_response(item)
