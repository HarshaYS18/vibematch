from pydantic import BaseModel, EmailStr, Field

from app.schemas.role_badge import RoleBadgeResponse


class DevLoginRequest(BaseModel):
    email: EmailStr
    username: str | None = None
    display_name: str | None = None
    device_id: str | None = None


class GoogleLoginRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None
    device_id: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    public_user_id: int
    username: str | None = None
    display_name: str | None = None
    roles: list[str]
    primary_role: str
    primary_role_badge: RoleBadgeResponse | None = None
    role_badges: list[RoleBadgeResponse] = Field(default_factory=list)