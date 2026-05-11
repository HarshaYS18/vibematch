from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.role_badge import RoleBadgeResponse


class UserVipSummaryResponse(BaseModel):
    vip_level: int = 0
    svip_level: int = 0
    vip_is_active: bool = True
    svip_is_active: bool = False
    svip_expires_at: datetime | None = None
    name_gradient_key: str = "default"
    name_gradient_colors: list[str] = Field(default_factory=list)


class UserWalletSummaryResponse(BaseModel):
    coin_balance: int = 0
    ruby_balance: int = 0
    lifetime_coins_spent: int = 0
    lifetime_rubies_earned: int = 0


class UserProfileUpdateRequest(BaseModel):
    display_name: str | None = Field(default=None, max_length=80)
    bio: str | None = Field(default=None, max_length=240)
    avatar_url: str | None = Field(default=None, max_length=500)
    date_of_birth: date | None = None
    gender: str | None = Field(default=None, max_length=30)
    profession: str | None = Field(default=None, max_length=80)
    marital_status: str | None = Field(default=None, max_length=30)
    friend_gender_preference: str | None = Field(default=None, max_length=30)
    friend_marital_preference: str | None = Field(default=None, max_length=30)
    interests: list[str] = Field(default_factory=list, max_length=40)


class UserMeResponse(BaseModel):
    id: int
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    bio: str | None = None
    date_of_birth: date | None = None
    gender: str | None = None
    profession: str | None = None
    marital_status: str | None = None
    friend_gender_preference: str | None = None
    friend_marital_preference: str | None = None
    interests: list[str] = Field(default_factory=list)
    roles: list[str]
    primary_role: str
    primary_role_badge: RoleBadgeResponse | None = None
    role_badges: list[RoleBadgeResponse] = Field(default_factory=list)
    vip: UserVipSummaryResponse | None = None
    wallet: UserWalletSummaryResponse | None = None
    is_active: bool
    is_banned: bool
    last_device_id: str | None = None
    last_login_at: datetime | None = None
    last_seen_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserRelationshipResponse(BaseModel):
    public_user_id: int
    is_following: bool = False
    follows_me: bool = False
    is_friend: bool = False
    blocked_by_me: bool = False
    blocked_me: bool = False
    can_follow: bool = True
    follow_block_reason: str | None = None
    followers_count: int = 0
    following_count: int = 0


class PublicUserProfileResponse(BaseModel):
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    bio: str | None = None
    date_of_birth: date | None = None
    gender: str | None = None
    profession: str | None = None
    marital_status: str | None = None
    friend_gender_preference: str | None = None
    friend_marital_preference: str | None = None
    interests: list[str] = Field(default_factory=list)
    primary_role: str
    primary_role_badge: RoleBadgeResponse | None = None
    role_badges: list[RoleBadgeResponse] = Field(default_factory=list)
    vip: UserVipSummaryResponse
    is_online: bool
    last_seen_at: datetime | None = None
    created_at: datetime
    relationship: UserRelationshipResponse | None = None


class UserSearchResultResponse(BaseModel):
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    primary_role: str
    primary_role_badge: RoleBadgeResponse | None = None
    role_badges: list[RoleBadgeResponse] = Field(default_factory=list)
    vip: UserVipSummaryResponse
    is_online: bool
    last_seen_at: datetime | None = None
    is_following: bool = False
    follows_me: bool = False
    is_friend: bool = False
    blocked_by_me: bool = False
    blocked_me: bool = False
    can_follow: bool = True


class UserSearchResponse(BaseModel):
    query: str
    users: list[UserSearchResultResponse] = Field(default_factory=list)
