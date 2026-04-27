from datetime import datetime
from pydantic import BaseModel

from app.models.special_permission import SpecialPermissionName


class GrantSpecialPermissionRequest(BaseModel):
    target_user_id: int
    permission: SpecialPermissionName
    reason: str
    expires_at: datetime | None = None


class RevokeSpecialPermissionRequest(BaseModel):
    special_permission_id: int
    reason: str


class SpecialPermissionResponse(BaseModel):
    id: int
    user_id: int
    permission: str
    granted_by_user_id: int
    reason: str
    is_active: bool
    expires_at: datetime | None = None
    created_at: datetime
    revoked_at: datetime | None = None
    revoked_by_user_id: int | None = None
    revoked_reason: str | None = None

    class Config:
        from_attributes = True


class SpecialPermissionActionResponse(BaseModel):
    message: str
    special_permission_id: int
    user_id: int
    permission: str
    is_active: bool