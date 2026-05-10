from datetime import datetime, timedelta

from pydantic import BaseModel, Field


class UserVipStatusResponse(BaseModel):
    user_id: int
    public_user_id: int
    vip_level: int
    svip_level: int
    vip_is_active: bool
    svip_is_active: bool
    svip_expires_at: datetime | None = None
    updated_by_user_id: int | None = None
    update_reason: str | None = None


class UserVipStatusUpdateRequest(BaseModel):
    vip_level: int = Field(default=0, ge=0, le=50)
    svip_level: int = Field(default=0, ge=0, le=10)
    vip_is_active: bool = True
    svip_is_active: bool = False
    svip_days: int | None = Field(default=30, ge=1, le=366)
    reason: str = Field(..., min_length=3, max_length=255)
