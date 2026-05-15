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
    comments_enabled: bool = True


class VibeCommentCreateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=500)
    parent_comment_id: int | None = None


class VibeShareCreateRequest(BaseModel):
    target_public_user_id: int | None = None
    share_channel: str = Field(default="inbox", max_length=30)


class VibeReportCreateRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=250)
    details: str | None = Field(default=None, max_length=2000)


class VibeReportReviewRequest(BaseModel):
    status: str = Field(pattern="^(PENDING|UNDER_REVIEW|ACTION_TAKEN|REJECTED|CLOSED)$")
    note: str | None = Field(default=None, max_length=2000)
    delete_post: bool = False


class VibeCommentResponse(BaseModel):
    id: int
    post_id: int
    parent_comment_id: int | None = None
    text: str
    author: VibeAuthorResponse
    is_pinned: bool = False
    can_pin: bool = False
    can_delete: bool = False
    liked_by_me: bool = False
    likes_count: int = 0
    created_at: datetime


class VibeCommentActionResponse(BaseModel):
    id: int
    post_id: int
    is_pinned: bool = False
    deleted: bool = False


class VibeCommentLikeResponse(BaseModel):
    comment_id: int
    liked_by_me: bool
    likes_count: int


class VibePostResponse(BaseModel):
    id: int
    caption: str
    media_type: str
    media_url: str | None = None
    tag: str | None = None
    mentions: list[str]
    uses_mention_all: bool
    comments_enabled: bool = True
    author: VibeAuthorResponse
    likes_count: int
    comments_count: int
    shares_count: int = 0
    saves_count: int = 0
    reports_count: int = 0
    views_count: int = 0
    liked_by_me: bool = False
    saved_by_me: bool = False
    created_at: datetime


class VibeFeedResponse(BaseModel):
    posts: list[VibePostResponse]


class VibeLikeResponse(BaseModel):
    post_id: int
    liked_by_me: bool
    likes_count: int


class VibeSaveResponse(BaseModel):
    post_id: int
    saved_by_me: bool
    saves_count: int


class VibeShareResponse(BaseModel):
    id: int
    post_id: int
    share_channel: str
    target_public_user_id: int | None = None
    shares_count: int
    created_at: datetime


class VibeReportResponse(BaseModel):
    id: int
    post_id: int
    reason: str
    status: str
    created_at: datetime


class VibeReportQueueItemResponse(BaseModel):
    id: int
    post_id: int
    reporter: VibeAuthorResponse
    post_author: VibeAuthorResponse
    post_caption: str
    post_media_type: str
    reason: str
    details: str | None = None
    status: str
    created_at: datetime


class VibeReportQueueResponse(BaseModel):
    reports: list[VibeReportQueueItemResponse]


class VibeDeleteResponse(BaseModel):
    post_id: int
    deleted: bool