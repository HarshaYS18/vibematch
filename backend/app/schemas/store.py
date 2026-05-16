from datetime import datetime
from pydantic import BaseModel, Field


class StoreItemResponse(BaseModel):
    item_id: str
    name: str
    category: str
    description: str | None = None
    price_coins: int
    duration_days: int | None = None
    asset_path: str | None = None
    image_url: str | None = None
    preview_url: str | None = None
    linked_theme_id: str | None = None
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
    image_url: str | None = None
    preview_url: str | None = None
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
    image_url: str | None = None
    expires_at: datetime | None = None


class EquippedStoreItemsResponse(BaseModel):
    avatar_frame: EquippedStoreItemResponse | None = None
    chat_bubble: EquippedStoreItemResponse | None = None
