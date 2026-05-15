from datetime import datetime

from pydantic import BaseModel, Field


class HomeBannerResponse(BaseModel):
    id: int
    placement: str
    title: str
    image_url: str
    target: str
    target_url: str | None = None
    description: str | None = None
    sort_order: int
    is_active: bool
    starts_at: datetime | None = None
    ends_at: datetime | None = None

    model_config = {"from_attributes": True}


class HomeBannerCreateRequest(BaseModel):
    placement: str = Field(..., min_length=1, max_length=40)
    title: str = Field(..., min_length=1, max_length=160)
    image_url: str = Field(..., min_length=1, max_length=1000)
    target: str = Field(default="event", max_length=40)
    target_url: str | None = Field(default=None, max_length=1000)
    description: str | None = None
    sort_order: int = Field(default=1, ge=1)
    is_active: bool = True
    starts_at: datetime | None = None
    ends_at: datetime | None = None
