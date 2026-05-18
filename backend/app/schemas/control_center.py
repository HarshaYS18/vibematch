from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class EconomyRuleLevelRequest(BaseModel):
    level: int = Field(..., gt=0)
    required_exp: int = Field(..., ge=0)


class EconomyRuleSetUpdateRequest(BaseModel):
    title: str = Field(..., min_length=2, max_length=140)
    levels: list[EconomyRuleLevelRequest]
    reason: str = Field(..., min_length=3, max_length=255)


class StoreCategoryUpsertRequest(BaseModel):
    category_key: str = Field(..., min_length=1, max_length=80)
    label: str = Field(..., min_length=1, max_length=140)
    description: str | None = None
    visibility: str = "public"
    sort_order: int = 0
    is_active: bool = True
    reason: str | None = None


class StoreItemUpsertRequest(BaseModel):
    item_id: str = Field(..., min_length=1, max_length=120)
    name: str = Field(..., min_length=1, max_length=140)
    category: str = Field(..., min_length=1, max_length=80)
    item_type: str
    description: str | None = None
    price_coins: int = Field(default=0, ge=0)
    currency_type: str = "coin"
    ownership_type: str = "permanent"
    duration_days: int | None = Field(default=None, ge=1)
    asset_path: str | None = None
    cdn_asset_url: str | None = None
    image_url: str | None = None
    thumbnail_url: str | None = None
    preview_url: str | None = None
    animation_url: str | None = None
    video_url: str | None = None
    visibility: str = "public"
    vip_required_level: int = Field(default=0, ge=0)
    svip_required_level: int = Field(default=0, ge=0)
    official_only: bool = False
    asset_version: int = Field(default=1, ge=1)
    catalog_version: int = Field(default=1, ge=1)
    is_active: bool = True
    is_featured: bool = False
    sort_order: int = 0
    reason: str | None = None


class ManifestImportRequest(BaseModel):
    manifest: dict[str, Any]
    reason: str | None = None


class StoreCategoryResponse(BaseModel):
    id: int
    category_key: str
    label: str
    description: str | None = None
    visibility: str
    sort_order: int
    is_active: bool
    is_system: bool
    updated_at: datetime | None = None
