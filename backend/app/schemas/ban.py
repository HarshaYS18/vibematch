from datetime import datetime
from pydantic import BaseModel


class BanUserRequest(BaseModel):
    target_user_id: int
    reason: str
    device_id: str | None = None


class UnbanUserRequest(BaseModel):
    target_user_id: int
    reason: str


class UnbanDeviceRequest(BaseModel):
    device_id: str
    reason: str


class UserBanResponse(BaseModel):
    id: int
    user_id: int
    banned_by_user_id: int
    ban_type: str
    ban_source: str
    reason: str
    starts_at: datetime
    expires_at: datetime | None = None
    is_active: bool
    device_id_snapshot: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class DeviceBanResponse(BaseModel):
    id: int
    device_id: str
    user_id: int | None = None
    banned_by_user_id: int
    reason: str
    triggered_by_rule: str | None = None
    ban_count_snapshot: int | None = None
    is_active: bool
    created_at: datetime
    lifted_at: datetime | None = None
    lifted_by_user_id: int | None = None
    lifted_reason: str | None = None

    class Config:
        from_attributes = True


class BanActionResponse(BaseModel):
    message: str
    user_ban_id: int | None = None
    device_ban_id: int | None = None
    target_user_id: int | None = None
    device_id: str | None = None
    expires_at: datetime | None = None
    is_device_banned: bool = False