from datetime import datetime

from pydantic import BaseModel


class AdminLogResponse(BaseModel):
    id: int
    actor_user_id: int | None = None
    target_user_id: int | None = None
    action: str
    resource_type: str | None = None
    resource_id: str | None = None
    reason: str | None = None
    metadata_json: dict | None = None
    ip_address: str | None = None
    device_id: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class LoginHistoryResponse(BaseModel):
    id: int
    user_id: int | None = None
    email: str
    provider: str
    provider_user_id: str
    device_id: str | None = None
    ip_address: str | None = None
    status: str
    failure_reason: str | None = None
    failure_detail: str | None = None
    is_success: bool
    created_at: datetime

    class Config:
        from_attributes = True