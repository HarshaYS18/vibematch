from datetime import datetime
from pydantic import BaseModel, Field


class RoomThemeResponse(BaseModel):
    theme_id: str
    name: str
    ownership_type: str = "free"
    price_coins: int = 0
    image_url: str | None = None
    thumbnail_url: str | None = None
    asset_path: str | None = None
    accent: str = "#12C7B7"
    overlay_opacity: float = 0.42
    is_default: bool = False
    is_owned: bool = False
    is_active: bool = True


class RoomThemePurchaseRequest(BaseModel):
    theme_id: str = Field(..., min_length=1, max_length=120)


class RoomThemeApplyRequest(BaseModel):
    theme_id: str = Field(..., min_length=1, max_length=120)


class RoomCoverPhotoUpdateRequest(BaseModel):
    cover_photo_url: str = Field(..., min_length=1, max_length=500)


class CustomRoomBackgroundSubmitRequest(BaseModel):
    image_url: str = Field(..., min_length=1, max_length=500)
    thumbnail_url: str | None = Field(default=None, max_length=500)
    room_public_id: str | None = Field(default=None, max_length=32)


class RoomThemeReviewResponse(BaseModel):
    review_public_id: str
    submitter_user_id: int
    room_public_id: str | None = None
    image_url: str
    thumbnail_url: str | None = None
    proposed_theme_id: str
    status: str
    review_note: str | None = None
    reviewed_by_user_id: int | None = None
    reviewed_at: datetime | None = None
    created_at: datetime


class RoomThemeReviewDecisionRequest(BaseModel):
    status: str = Field(..., pattern="^(approved|rejected)$")
    review_note: str = Field(..., min_length=3, max_length=500)
