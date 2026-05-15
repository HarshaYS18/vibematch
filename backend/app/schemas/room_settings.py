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
    has_lock_password: bool = False
    background_theme_id: str = "default"
    announcement_text: str | None = None
    announcement_updated_at: datetime | None = None
    announcement_updated_by_user_id: int | None = None


class RoomBackgroundUpdateRequest(BaseModel):
    background_theme_id: str = Field(min_length=1, max_length=80)


class RoomAnnouncementUpdateRequest(BaseModel):
    announcement_text: str = Field(default="", max_length=500)


class RoomAccessSettingsUpdateRequest(BaseModel):
    language: str | None = Field(default=None, min_length=1, max_length=40)
    mode: str | None = Field(default=None, min_length=1, max_length=40)
    lock_password: str | None = Field(default=None, max_length=80)
    allow_screenshots: bool | None = None
