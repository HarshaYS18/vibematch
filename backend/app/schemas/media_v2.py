from datetime import datetime

from pydantic import BaseModel, Field


class MediaUploadSessionCreateRequest(BaseModel):
    purpose: str = Field(min_length=2, max_length=50)
    filename: str = Field(min_length=1, max_length=255)
    content_type: str = Field(min_length=1, max_length=120)
    size_bytes: int = Field(gt=0)


class MediaDirectUploadPartResponse(BaseModel):
    part_number: int
    url: str
    headers: dict[str, str] = Field(default_factory=dict)


class MediaUploadSessionResponse(BaseModel):
    session_id: str
    media_id: str
    upload_mode: str
    upload_url: str | None = None
    upload_headers: dict[str, str] = Field(default_factory=dict)
    part_size_bytes: int | None = None
    parts: list[MediaDirectUploadPartResponse] = Field(default_factory=list)
    expires_at: datetime


class MediaUploadCompletePart(BaseModel):
    part_number: int = Field(ge=1)
    etag: str = Field(min_length=1, max_length=300)


class MediaUploadCompleteRequest(BaseModel):
    parts: list[MediaUploadCompletePart] = Field(default_factory=list)


class MediaVariantResponse(BaseModel):
    variant_key: str
    kind: str
    url: str
    content_type: str
    width: int | None = None
    height: int | None = None
    bitrate_kbps: int | None = None
    size_bytes: int


class MediaAssetStatusResponse(BaseModel):
    media_id: str
    url: str
    thumbnail_url: str | None = None
    content_type: str
    size_bytes: int
    upload_status: str
    processing_status: str
    moderation_status: str
    expires_at: datetime | None = None
    variants: list[MediaVariantResponse] = Field(default_factory=list)
