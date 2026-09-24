from datetime import datetime
from pydantic import BaseModel, Field


class StoreItemResponse(BaseModel):
    item_id: str
    name: str
    category: str
    item_type: str | None = None
    description: str | None = None
    price_coins: int
    currency_type: str = "coin"
    ownership_type: str = "permanent"
    duration_days: int | None = None
    asset_path: str | None = None
    cdn_asset_url: str | None = None
    image_url: str | None = None
    thumbnail_url: str | None = None
    preview_url: str | None = None
    animation_url: str | None = None
    video_url: str | None = None
    linked_theme_id: str | None = None
    visibility: str = "public"
    asset_version: int = 1
    catalog_version: int = 1
    is_active: bool = True
    is_featured: bool = False
    is_owned: bool = False
    is_equipped: bool = False
    expires_at: datetime | None = None


class StoreCatalogResponse(BaseModel):
    categories: list[str]
    sections: dict[str, list[StoreItemResponse]]


class StorePurchaseRequest(BaseModel):
    item_id: str = Field(..., min_length=1, max_length=120)
    purchase_id: str | None = Field(default=None, min_length=8, max_length=36)


class StoreEquipRequest(BaseModel):
    item_id: str = Field(..., min_length=1, max_length=120)
    equipped: bool = True


class InventoryItemResponse(BaseModel):
    item_id: str
    name: str
    category: str
    source: str
    is_equipped: bool
    duration_days: int | None = None
    asset_path: str | None = None
    cdn_asset_url: str | None = None
    image_url: str | None = None
    thumbnail_url: str | None = None
    preview_url: str | None = None
    animation_url: str | None = None
    video_url: str | None = None
    linked_theme_id: str | None = None
    expires_at: datetime | None = None
    created_at: datetime


class InventoryResponse(BaseModel):
    categories: list[str]
    sections: dict[str, list[InventoryItemResponse]]


class EquippedStoreItemResponse(BaseModel):
    item_id: str | None = None
    name: str | None = None
    category: str
    asset_path: str | None = None
    cdn_asset_url: str | None = None
    image_url: str | None = None
    thumbnail_url: str | None = None
    expires_at: datetime | None = None


class EquippedStoreItemsResponse(BaseModel):
    avatar_frame: EquippedStoreItemResponse | None = None
    chat_bubble: EquippedStoreItemResponse | None = None
    text_bubble: EquippedStoreItemResponse | None = None
    entrance_effect: EquippedStoreItemResponse | None = None
    profile_decoration: EquippedStoreItemResponse | None = None
    name_gradient: EquippedStoreItemResponse | None = None
