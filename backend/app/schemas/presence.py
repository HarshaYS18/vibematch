from datetime import datetime

from pydantic import BaseModel, Field


class PresenceHeartbeatRequest(BaseModel):
    room_public_id: str | None = Field(default=None, max_length=32)
    room_name: str | None = Field(default=None, max_length=120)
    room_mode: str | None = Field(default=None, max_length=40)
    is_secret: bool = False


class RoomPresenceEnterRequest(BaseModel):
    room_public_id: str = Field(min_length=2, max_length=32)
    room_name: str = Field(min_length=1, max_length=120)
    room_mode: str | None = Field(default=None, max_length=40)
    is_secret: bool = False


class PresenceResponse(BaseModel):
    public_user_id: int
    is_online: bool
    last_seen_at: datetime | None = None
    in_room: bool = False
    room_public_id: str | None = None
    room_name: str | None = None
    room_mode: str | None = None
    room_entered_at: datetime | None = None


class PresenceBatchRequest(BaseModel):
    public_user_ids: list[int] = Field(default_factory=list, max_length=100)


class PresenceBatchResponse(BaseModel):
    items: list[PresenceResponse]
