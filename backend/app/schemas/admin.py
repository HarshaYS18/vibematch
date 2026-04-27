from pydantic import BaseModel

from app.models.role import RoleName


class AdminUserResponse(BaseModel):
    id: int
    public_user_id: int
    display_custom_id: int | None = None
    display_name: str | None = None
    username: str | None = None
    is_active: bool
    is_banned: bool
    roles: list[str]
    primary_role: str


class AssignRoleRequest(BaseModel):
    target_user_id: int
    role: RoleName
    reason: str


class AssignRoleResponse(BaseModel):
    message: str
    target_user_id: int
    assigned_role: str
    assigned_by_user_id: int