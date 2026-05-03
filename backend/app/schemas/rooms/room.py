from pydantic import BaseModel, ConfigDict, Field


class RoomTrendingResponse(BaseModel):
    id: str = Field(..., description="Human-readable public room ID, for example VM120451.")
    name: str
    subtitle: str | None = None
    language: str
    mode: str
    type: str
    online_count: int
    trending_score: int
    followed_friends_inside: list[str] = Field(default_factory=list)
    cover_image_url: str | None = None


class RoomCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    language: str = Field(default="English", min_length=1, max_length=40)
    mode: str = Field(default="Open", min_length=1, max_length=40)
    type: str = Field(default="Chat", min_length=1, max_length=40)
    cover_image_url: str | None = Field(default=None, max_length=500)


class RoomCreateResponse(RoomTrendingResponse):
    owner_user_id: int
    is_active: bool
    is_secret: bool
    is_locked: bool
    is_members_only: bool

    model_config = ConfigDict(from_attributes=True)


class RoomDetailResponse(RoomTrendingResponse):
    owner_user_id: int | None = None
    is_active: bool
    is_secret: bool
    is_locked: bool
    is_members_only: bool

    model_config = ConfigDict(from_attributes=True)
