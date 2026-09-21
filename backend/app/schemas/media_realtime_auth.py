from pydantic import BaseModel, Field


class MediaRealtimeVerifyRequest(BaseModel):
    room_public_id: str | None = Field(default=None, max_length=80)
    device_id: str | None = Field(default=None, max_length=255)
    requested_action: str = Field(default="join_room", max_length=80)
    media_node_id: str | None = Field(default=None, max_length=120)


class MediaRealtimeUserResponse(BaseModel):
    user_id: int
    public_user_id: int
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    roles: list[str]
    primary_role: str
    is_active: bool
    is_banned: bool


class MediaRealtimeVerifyResponse(BaseModel):
    allowed: bool
    reason: str | None = None
    user: MediaRealtimeUserResponse
    room_public_id: str | None = None
    requested_action: str
    permissions: list[str]
    mediasoup_context: dict
