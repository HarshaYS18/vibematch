from pydantic import BaseModel, EmailStr


class DevLoginRequest(BaseModel):
    email: EmailStr
    username: str | None = None
    display_name: str | None = None
    device_id: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    public_user_id: int
    roles: list[str]