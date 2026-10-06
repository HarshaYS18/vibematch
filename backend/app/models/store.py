from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class StoreItemCategory(str, Enum):
    AVATAR_FRAME = "avatar_frame"
    CHAT_BUBBLE = "chat_bubble"
    ENTRANCE_EFFECT = "entrance_effect"
    PROFILE_DECORATION = "profile_decoration"
    TEXT_BUBBLE = "text_bubble"
    NAME_GRADIENT = "name_gradient"
    SPECIAL_CUSTOM_ID = "special_custom_id"
    ROOM_BACKGROUND = "room_background"
    PROFILE_THEME = "profile_theme"
    GIFT = "gift"
    GIFT_CATEGORY = "gift_category"
    LOVE_BOND_CARD = "love_bond_card"
    EVENT_ASSET = "event_asset"
    BADGE = "badge"
    THEME = "theme"


class StoreCategory(Base):
    __tablename__ = "store_categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    category_key: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    label: Mapped[str] = mapped_column(String(140), nullable=False)
    description: Mapped[str | None] = mapped_column(String(400), nullable=True)
    visibility: Mapped[str] = mapped_column(String(40), default="public", index=True, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True, nullable=False)
    is_system: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    updated_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class StoreItem(Base):
    __tablename__ = "store_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    item_id: Mapped[str] = mapped_column(String(120), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(140), nullable=False)
    category: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    item_type: Mapped[str] = mapped_column(String(60), default="store_item", index=True, nullable=False)
    description: Mapped[str | None] = mapped_column(String(300), nullable=True)
    price_coins: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    currency_type: Mapped[str] = mapped_column(String(30), default="coin", nullable=False)
    ownership_type: Mapped[str] = mapped_column(String(40), default="permanent", nullable=False)
    duration_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    asset_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    cdn_asset_url: Mapped[str | None] = mapped_column(String(700), nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column(String(700), nullable=True)
    preview_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    animation_url: Mapped[str | None] = mapped_column(String(700), nullable=True)
    video_url: Mapped[str | None] = mapped_column(String(700), nullable=True)
    linked_theme_id: Mapped[str | None] = mapped_column(String(120), index=True, nullable=True)
    visibility: Mapped[str] = mapped_column(String(40), default="public", index=True, nullable=False)
    vip_required_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    svip_required_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    official_only: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    availability_starts_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    availability_ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    asset_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    cache_key: Mapped[str | None] = mapped_column(String(120), nullable=True)
    catalog_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    admin_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class UserStoreInventory(Base):
    __tablename__ = "user_store_inventory"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    item_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    category: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    source: Mapped[str] = mapped_column(String(60), nullable=False, default="purchase")
    is_equipped: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    ownership_type: Mapped[str] = mapped_column(String(40), default="purchase", nullable=False)
    granted_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class StoreAssetManifest(Base):
    __tablename__ = "store_asset_manifests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    manifest_key: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="draft", index=True, nullable=False)
    raw_payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    validation_errors_json: Mapped[list | None] = mapped_column(JSON, nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    published_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    published_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class StorePurchaseOperation(Base):
    __tablename__ = "store_purchase_operations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    purchase_id: Mapped[str] = mapped_column(String(36), unique=True, nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    item_id: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(40), nullable=False, default="PENDING", index=True)
    economy_transaction_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    compensation_transaction_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    lease_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
    error_detail: Mapped[str | None] = mapped_column(String(700), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
