from datetime import datetime

from pydantic import BaseModel, Field


class RoomSettingsResponse(BaseModel):
    room_public_id: str
    name: str | None = None
    language: str | None = None
    mode: str | None = None
    is_secret: bool = False
    is_locked: bool = False
    is_members_only: bool = False
    allow_screenshots: bool = True
    room_images_enabled: bool = True
    guest_messages_enabled: bool = True
    apply_only_mode_enabled: bool = False
    has_lock_password: bool = False
    cover_photo_url: str | None = None
    background_theme_id: str = "default"
    seat_layout_id: str = "5x2"
    announcement_text: str | None = None
    announcement_updated_at: datetime | None = None
    announcement_updated_by_user_id: int | None = None


class RoomBackgroundUpdateRequest(BaseModel):
    background_theme_id: str = Field(min_length=1, max_length=80)


class RoomSeatLayoutUpdateRequest(BaseModel):
    seat_layout_id: str = Field(min_length=2, max_length=24)


class RoomNameUpdateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class RoomAnnouncementUpdateRequest(BaseModel):
    announcement_text: str = Field(default="", max_length=500)


class RoomAccessSettingsUpdateRequest(BaseModel):
    language: str | None = Field(default=None, min_length=1, max_length=40)
    mode: str | None = Field(default=None, min_length=1, max_length=40)
    lock_password: str | None = Field(default=None, max_length=80)
    allow_screenshots: bool | None = None
