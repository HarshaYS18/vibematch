from datetime import datetime

from pydantic import BaseModel


class UserMeResponse(BaseModel):
    id: int
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    roles: list[str]
    primary_role: str
    is_active: bool
    is_banned: bool
    last_device_id: str | None = None
    last_login_at: datetime | None = None
    last_seen_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True