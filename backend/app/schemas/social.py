from datetime import datetime
from pydantic import BaseModel


class PublicUserSummary(BaseModel):
    id: int
    public_user_id: int
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None


class FollowStatusResponse(BaseModel):
    target_user: PublicUserSummary
    is_following: bool
    is_followed_by: bool
    is_friends: bool
    action_label: str


class FollowActionResponse(FollowStatusResponse):
    status: str
    created_at: datetime | None = None


class FollowingListResponse(BaseModel):
    users: list[PublicUserSummary]


class FollowersListResponse(BaseModel):
    users: list[PublicUserSummary]


class FriendsListResponse(BaseModel):
    users: list[PublicUserSummary]
