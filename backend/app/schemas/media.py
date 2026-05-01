from pydantic import BaseModel, Field


class MediaUploadResponse(BaseModel):
    storage_backend: str = Field(..., examples=["local"])
    storage_key: str = Field(..., examples=["avatars/2026/05/01/file.png"])
    public_url: str = Field(..., examples=["/media/avatars/2026/05/01/file.png"])
    filename: str
    content_type: str
    size_bytes: int
    size_mb: float
    bucket: str
    moderation_status: str = Field(
        default="local_preview_only",
        description="Local testing status. Production upload flow should run AI/official moderation where required.",
    )
