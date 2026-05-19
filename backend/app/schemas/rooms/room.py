from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

from app.schemas.role_badge import RoleBadgeResponse
from app.schemas.store import EquippedStoreItemsResponse
from app.schemas.user import UserVipSummaryResponse


class RoomCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    subtitle: str | None = Field(default=None, max_length=240)
    avatar_url: str | None = Field(default=None, max_length=500)
    cover_photo_url: str | None = Field(default=None, max_length=500)
    language: str = Field(default="English", max_length=40)
    mode: str = Field(default="Open", max_length=40)
    type: str = Field(default="Chat", max_length=40)
    lock_password: str | None = Field(default=None, min_length=1, max_length=64)
    allow_screenshots: bool = True


class RoomModeUpdateRequest(BaseModel):
    mode: str = Field(..., min_length=2, max_length=40)
    lock_password: str | None = Field(default=None, min_length=1, max_length=64)


class RoomJoinRequest(BaseModel):
    lock_password: str | None = Field(default=None, min_length=1, max_length=64)


class RoomTrendingResponse(BaseModel):
    id: str = Field(..., description="Human-readable public room ID, for example VM120451.")
    name: str
    subtitle: str | None = None
    avatar_url: str | None = None
    cover_photo_url: str | None = None
    language: str
    mode: str
    type: str
    online_count: int
    trending_score: int
    followed_friends_inside: list[str] = Field(default_factory=list)
    allow_screenshots: bool = True


class RoomDetailResponse(RoomTrendingResponse):
    owner_user_id: int | None = None
    is_active: bool
    is_secret: bool
    is_locked: bool
    is_members_only: bool
    has_lock_password: bool = False

    model_config = ConfigDict(from_attributes=True)


class RoomParticipantUserResponse(BaseModel):
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    primary_role: str
    primary_role_badge: RoleBadgeResponse | None = None
    role_badges: list[RoleBadgeResponse] = Field(default_factory=list)
    vip: UserVipSummaryResponse
    equipped_items: EquippedStoreItemsResponse | None = None
    sending_level: int = 0
    receiving_level: int = 0
    sent_exp: int = 0
    received_exp: int = 0
    monthly_gift_coins_sent: int = 0
    monthly_gift_coins_received: int = 0
    is_owner: bool = False
    is_member: bool = False
    is_room_admin: bool = False
    is_online: bool = False
    list_section: str = "visitor"
    joined_at: datetime
    last_seen_at: datetime


class RoomMemberActionRequest(BaseModel):
    public_user_id: int


class RoomJoinResponse(BaseModel):
    room: RoomDetailResponse
    participants: list[RoomParticipantUserResponse] = Field(default_factory=list)
    joined_user: RoomParticipantUserResponse | None = None
    should_show_entered_message: bool = False
    closed_room_ids: list[str] = Field(default_factory=list)


class RoomLeaveResponse(BaseModel):
    room_id: str
    online_count: int
    left: bool


class RoomParticipantsResponse(BaseModel):
    room_id: str
    online_count: int
    participants: list[RoomParticipantUserResponse] = Field(default_factory=list)
