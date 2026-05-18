from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.role import RoleName
from app.models.special_permission import SpecialPermissionName
from app.models.store import StoreAssetManifest, StoreCategory, StoreItem
from app.models.user import User
from app.services.audit_log_service import create_admin_log
from app.services.permissions import room_permission_service
from app.services.role_service import get_primary_role

STORE_ITEM_TYPES = {
    "avatar_frame",
    "entrance_effect",
    "profile_decoration",
    "text_bubble",
    "name_gradient",
    "special_custom_id",
    "room_background",
    "gift",
    "gift_category",
    "event_asset",
    "badge",
    "theme",
    "chat_bubble",
    "profile_theme",
}


def _require_store_manager(db: Session, actor: User) -> None:
    if get_primary_role(actor) in {RoleName.FOUNDER_OWNER, RoleName.OWNER, RoleName.SUPERADMIN}:
        return
    if room_permission_service.has_active_special_permission(db, actor, SpecialPermissionName.MANAGE_STORE_CATALOG):
        return
    raise HTTPException(status_code=403, detail="Store catalog management requires Control Center permission")


def _safe_key(value: str, *, label: str) -> str:
    key = (value or "").strip().lower().replace(" ", "_")
    if not key or len(key) > 80 or not all(ch.isalnum() or ch in {"_", "-"} for ch in key):
        raise HTTPException(status_code=400, detail=f"{label} must be a stable key")
    return key


def _validate_url(url: str | None) -> str | None:
    text = (url or "").strip()
    if not text:
        return None
    lowered = text.lower()
    if lowered.endswith((".html", ".js")) or "javascript:" in lowered or "<script" in lowered:
        raise HTTPException(status_code=400, detail="Store assets cannot reference HTML or JavaScript")
    if not (lowered.startswith("https://") or lowered.startswith("http://") or lowered.startswith("assets/") or lowered.startswith("/static/")):
        raise HTTPException(status_code=400, detail="Asset URLs must be CDN/http/static paths")
    return text


def seed_default_categories(db: Session) -> None:
    defaults = [
        ("chat_bubble", "Chat Bubbles", 10),
        ("avatar_frame", "Avatar Frames", 20),
        ("room_background", "Room Backgrounds", 30),
        ("entrance_effect", "Entrance Effects", 40),
        ("profile_decoration", "Profile Decorations", 50),
        ("text_bubble", "Text Bubbles", 60),
        ("name_gradient", "Name Gradients", 70),
        ("special_custom_id", "Special Custom IDs", 80),
        ("gift", "Gifts", 90),
        ("badge", "Badges", 100),
        ("theme", "Themes", 110),
        ("event_asset", "Event Assets", 120),
    ]
    for key, label, sort_order in defaults:
        row = db.query(StoreCategory).filter(StoreCategory.category_key == key).first()
        if row is None:
            db.add(StoreCategory(category_key=key, label=label, sort_order=sort_order, is_system=True))
    db.flush()


def list_categories(db: Session) -> list[dict]:
    seed_default_categories(db)
    rows = db.query(StoreCategory).order_by(StoreCategory.sort_order.asc(), StoreCategory.id.asc()).all()
    return [category_payload(row) for row in rows]


def category_payload(row: StoreCategory) -> dict:
    return {
        "id": row.id,
        "category_key": row.category_key,
        "label": row.label,
        "description": row.description,
        "visibility": row.visibility,
        "sort_order": row.sort_order,
        "is_active": row.is_active,
        "is_system": row.is_system,
        "updated_at": row.updated_at,
    }


def upsert_category(db: Session, *, actor: User, data: dict[str, Any]) -> dict:
    _require_store_manager(db, actor)
    key = _safe_key(str(data.get("category_key") or ""), label="Category key")
    row = db.query(StoreCategory).filter(StoreCategory.category_key == key).first()
    if row is None:
        row = StoreCategory(category_key=key, created_by_user_id=actor.id)
        db.add(row)
    row.label = str(data.get("label") or key.replace("_", " ").title()).strip()
    row.description = (data.get("description") or None)
    row.visibility = str(data.get("visibility") or "public")
    row.sort_order = int(data.get("sort_order") or 0)
    row.is_active = bool(data.get("is_active", True))
    row.updated_by_user_id = actor.id
    row.reason = data.get("reason")
    db.commit()
    create_admin_log(db=db, action="STORE_CATEGORY_UPSERTED", actor_user_id=actor.id, resource_type="store_category", resource_id=key, reason=row.reason, metadata_json=category_payload(row))
    return category_payload(row)


def item_payload(row: StoreItem) -> dict:
    return {
        "id": row.id,
        "item_id": row.item_id,
        "name": row.name,
        "category": row.category,
        "item_type": row.item_type,
        "description": row.description,
        "price_coins": row.price_coins,
        "currency_type": row.currency_type,
        "ownership_type": row.ownership_type,
        "duration_days": row.duration_days,
        "asset_path": row.asset_path,
        "cdn_asset_url": row.cdn_asset_url,
        "image_url": row.image_url,
        "thumbnail_url": row.thumbnail_url,
        "preview_url": row.preview_url,
        "animation_url": row.animation_url,
        "video_url": row.video_url,
        "visibility": row.visibility,
        "vip_required_level": row.vip_required_level,
        "svip_required_level": row.svip_required_level,
        "official_only": row.official_only,
        "asset_version": row.asset_version,
        "catalog_version": row.catalog_version,
        "is_active": row.is_active,
        "is_featured": row.is_featured,
        "sort_order": row.sort_order,
        "updated_at": row.updated_at,
    }


def list_items(db: Session, category: str | None = None) -> list[dict]:
    query = db.query(StoreItem)
    if category:
        query = query.filter(StoreItem.category == category)
    rows = query.order_by(StoreItem.category.asc(), StoreItem.sort_order.asc(), StoreItem.id.asc()).all()
    return [item_payload(row) for row in rows]


def upsert_item(db: Session, *, actor: User, data: dict[str, Any]) -> dict:
    _require_store_manager(db, actor)
    item_id = _safe_key(str(data.get("item_id") or ""), label="Item ID")
    category = _safe_key(str(data.get("category") or ""), label="Category")
    item_type = _safe_key(str(data.get("item_type") or category), label="Item type")
    if item_type not in STORE_ITEM_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported store item type")
    price = int(data.get("price_coins") or 0)
    if price < 0:
        raise HTTPException(status_code=400, detail="Store item price cannot be negative")
    row = db.query(StoreItem).filter(StoreItem.item_id == item_id).first()
    if row is None:
        row = StoreItem(item_id=item_id, name=item_id.replace("_", " ").title(), category=category)
        db.add(row)
    row.name = str(data.get("name") or row.name).strip()
    row.category = category
    row.item_type = item_type
    row.description = data.get("description")
    row.price_coins = price
    row.currency_type = str(data.get("currency_type") or "coin")
    row.ownership_type = str(data.get("ownership_type") or "permanent")
    row.duration_days = None if data.get("duration_days") in {None, ""} else int(data.get("duration_days"))
    row.asset_path = data.get("asset_path")
    row.cdn_asset_url = _validate_url(data.get("cdn_asset_url"))
    row.image_url = _validate_url(data.get("image_url"))
    row.thumbnail_url = _validate_url(data.get("thumbnail_url"))
    row.preview_url = _validate_url(data.get("preview_url"))
    row.animation_url = _validate_url(data.get("animation_url"))
    row.video_url = _validate_url(data.get("video_url"))
    row.visibility = str(data.get("visibility") or "public")
    row.vip_required_level = int(data.get("vip_required_level") or 0)
    row.svip_required_level = int(data.get("svip_required_level") or 0)
    row.official_only = bool(data.get("official_only", False))
    row.asset_version = int(data.get("asset_version") or row.asset_version or 1)
    row.catalog_version = int(data.get("catalog_version") or row.catalog_version or 1)
    row.is_active = bool(data.get("is_active", True))
    row.is_featured = bool(data.get("is_featured", False))
    row.sort_order = int(data.get("sort_order") or 0)
    row.admin_notes = data.get("reason")
    db.commit()
    create_admin_log(db=db, action="STORE_ITEM_UPSERTED", actor_user_id=actor.id, resource_type="store_item", resource_id=item_id, reason=data.get("reason"), metadata_json=item_payload(row))
    return item_payload(row)


def preview_manifest(payload: dict[str, Any]) -> dict:
    categories = payload.get("categories") if isinstance(payload.get("categories"), list) else []
    items = payload.get("items") if isinstance(payload.get("items"), list) else []
    errors: list[str] = []
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            errors.append(f"items[{index}] must be an object")
            continue
        try:
            _safe_key(str(item.get("item_id") or ""), label="Item ID")
            _safe_key(str(item.get("category") or ""), label="Category")
            _validate_url(item.get("cdn_asset_url") or item.get("image_url") or item.get("thumbnail_url") or item.get("animation_url") or item.get("video_url"))
        except HTTPException as exc:
            errors.append(f"items[{index}]: {exc.detail}")
    return {"valid": not errors, "category_count": len(categories), "item_count": len(items), "errors": errors}


def import_manifest(db: Session, *, actor: User, payload: dict[str, Any], reason: str | None = None) -> dict:
    _require_store_manager(db, actor)
    preview = preview_manifest(payload)
    manifest = StoreAssetManifest(
        manifest_key=str(payload.get("manifest_key") or f"manifest_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"),
        version=int(payload.get("version") or 1),
        status="published" if preview["valid"] else "rejected",
        raw_payload_json=payload,
        validation_errors_json=preview["errors"],
        created_by_user_id=actor.id,
        published_by_user_id=actor.id if preview["valid"] else None,
        published_at=datetime.utcnow() if preview["valid"] else None,
        reason=reason,
    )
    db.add(manifest)
    db.flush()
    if not preview["valid"]:
        db.commit()
        return {"manifest_id": manifest.id, **preview}
    for category in payload.get("categories") or []:
        if isinstance(category, dict):
            upsert_category(db, actor=actor, data={**category, "reason": reason})
    for item in payload.get("items") or []:
        if isinstance(item, dict):
            upsert_item(db, actor=actor, data={**item, "reason": reason})
    create_admin_log(db=db, action="STORE_MANIFEST_IMPORTED", actor_user_id=actor.id, resource_type="store_manifest", resource_id=str(manifest.id), reason=reason, metadata_json=preview)
    return {"manifest_id": manifest.id, **preview}
