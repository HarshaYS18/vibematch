from datetime import datetime

from pydantic import BaseModel, Field


class UserAppSettingsResponse(BaseModel):
    settings: dict = Field(default_factory=dict)
    updated_at: datetime | None = None


class UserAppSettingsUpdate(BaseModel):
    settings: dict = Field(default_factory=dict)


class BlockedUserResponse(BaseModel):
    public_user_id: int
    display_name: str
    username: str | None = None
    avatar_url: str | None = None
