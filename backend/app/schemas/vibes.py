from datetime import datetime
from pydantic import BaseModel, Field


class VibeAuthorResponse(BaseModel):
    id: int
    public_user_id: int
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None


class VibePostCreateRequest(BaseModel):
    caption: str = Field(min_length=1, max_length=2000)
    media_type: str = Field(default="text", pattern="^(text|photo|video)$")
    media_url: str | None = Field(default=None, max_length=1000)
    tag: str | None = Field(default=None, max_length=50)
    mentions: list[str] = Field(default_factory=list, max_length=50)
    uses_mention_all: bool = False


class VibeCommentCreateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=500)


class VibeCommentResponse(BaseModel):
    id: int
    post_id: int
    text: str
    author: VibeAuthorResponse
    created_at: datetime


class VibePostResponse(BaseModel):
    id: int
    caption: str
    media_type: str
    media_url: str | None = None
    tag: str | None = None
    mentions: list[str]
    uses_mention_all: bool
    author: VibeAuthorResponse
    likes_count: int
    comments_count: int
    shares_count: int = 0
    views_count: int = 0
    liked_by_me: bool = False
    created_at: datetime


class VibeFeedResponse(BaseModel):
    posts: list[VibePostResponse]


class VibeLikeResponse(BaseModel):
    post_id: int
    liked_by_me: bool
    likes_count: int


class VibeDeleteResponse(BaseModel):
    post_id: int
    deleted: bool
