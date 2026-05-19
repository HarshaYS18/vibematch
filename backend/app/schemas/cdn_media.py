from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class CdnMediaAssetResponse(BaseModel):
    id: int
    public_id: str
    owner_user_id: int | None
    public_user_id: int | None
    media_type: str
    object_key: str
    public_url: str
    thumbnail_url: str | None
    mime_type: str
    size_bytes: int
    upload_status: str
    moderation_status: str
    deletion_status: str
    linked_entity_type: str | None
    linked_entity_id: str | None
    moderation_provider: str | None
    moderation_model: str | None
    moderation_summary: str | None
    human_review_status: str | None
    review_reason: str | None
    deletion_error: str | None
    metadata_json: dict[str, Any] | None
    is_active_reference: bool
    expires_at: datetime | None
    deleted_at: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MediaSafetySettingResponse(BaseModel):
    id: int
    key: str
    value_json: dict[str, Any]
    description: str | None
    updated_by_user_id: int | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MediaSafetySettingUpdateRequest(BaseModel):
    value_json: dict[str, Any] = Field(default_factory=dict)
    description: str | None = None
    reason: str | None = None


class CdnMediaDashboardResponse(BaseModel):
    total_count: int
    pending_review_count: int
    deletion_failed_count: int
    inbox_expiring_count: int
    recent_assets: list[CdnMediaAssetResponse]


class CdnMediaActionRequest(BaseModel):
    reason: str = Field(min_length=2, max_length=500)


class CdnMediaCleanupResponse(BaseModel):
    checked: int
    deleted: int
    failed: int
