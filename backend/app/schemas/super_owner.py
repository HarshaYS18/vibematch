from datetime import datetime

from pydantic import BaseModel, Field

from app.models.special_permission import SpecialPermissionName


class SuperOwnerReasonRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=255)


class SuperOwnerMintCoinsRequest(SuperOwnerReasonRequest):
    target_pool_type: str = Field(..., min_length=3, max_length=80)
    amount: int = Field(..., gt=0)
    target_user_id: int | None = None
    request_id: str | None = Field(default=None, min_length=8, max_length=36)


class SuperOwnerSendCoinsAllRequest(SuperOwnerReasonRequest):
    coin_amount: int = Field(..., gt=0, le=10_000_000)
    active_only: bool = True


class SuperOwnerCustomIdRequest(SuperOwnerReasonRequest):
    target_user_id: int
    display_custom_id: int | None = Field(default=None, ge=1)


class SuperOwnerStealthRequest(SuperOwnerReasonRequest):
    target_user_id: int
    enabled: bool


class SuperOwnerSpecialPermissionGrantRequest(SuperOwnerReasonRequest):
    target_user_id: int
    permission: SpecialPermissionName
    expires_at: datetime | None = None


class SuperOwnerVipAdjustmentRequest(SuperOwnerReasonRequest):
    target_user_id: int
    vip_level: int = Field(default=0, ge=0, le=100)
    svip_level: int = Field(default=0, ge=0, le=100)
    vip_is_active: bool = True
    svip_is_active: bool = False
    svip_expires_at: datetime | None = None


class SuperOwnerLevelAdjustmentRequest(SuperOwnerReasonRequest):
    target_user_id: int
    send_exp_total: int | None = Field(default=None, ge=0)
    receive_exp_total: int | None = Field(default=None, ge=0)
    ruby_total: int | None = Field(default=None, ge=0)


class SuperOwnerInboxLockCodeRequest(SuperOwnerReasonRequest):
    user_identifier: str = Field(..., min_length=1, max_length=64, description="internal user id, public_user_id, or display_custom_id")
    lock_code: str = Field(..., min_length=4, max_length=12)
    mode: str = Field(default="reset", pattern="^(setup|reset)$")


class SuperOwnerPoolResponse(BaseModel):
    id: int
    owner_user_id: int | None
    pool_type: str
    balance: int
    reserved_balance: int
    status: str


class SuperOwnerWalletResponse(BaseModel):
    user_id: int
    coin_balance: int
    ruby_balance: int
    lifetime_coins_spent: int
    lifetime_coins_received_as_gifts: int
    lifetime_rubies_earned: int


class SuperOwnerActionResponse(BaseModel):
    message: str
    resource_id: str | None = None


class SuperOwnerInboxLockCodeResponse(BaseModel):
    message: str
    user_id: int
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str | None = None
    lock_enabled: bool
    recovery_requested: bool
    mode: str


class SuperOwnerVipResponse(BaseModel):
    user_id: int
    vip_level: int
    svip_level: int
    vip_is_active: bool
    svip_is_active: bool
    svip_expires_at: datetime | None = None


class SuperOwnerLogResponse(BaseModel):
    id: int
    actor_user_id: int | None = None
    target_user_id: int | None = None
    action: str
    resource_type: str | None = None
    resource_id: str | None = None
    reason: str | None = None
    created_at: datetime


class SuperOwnerReviewDetailResponse(BaseModel):
    id: int
    kind: str
    title: str
    status: str
    reason: str | None = None
    metadata: dict | None = None
    created_at: datetime