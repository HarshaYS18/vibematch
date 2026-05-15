from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.schemas.game_pools import GamePoolResponse


class LuckyGiftMultiplierRule(BaseModel):
    multiplier: int = Field(..., ge=1, le=1000)
    weight: int = Field(..., ge=0, le=1_000_000)
    difficulty: str = Field(default="easy", max_length=40)


class LuckyGiftPropsResponse(BaseModel):
    game_key: str
    testing_mode_enabled: bool
    min_multiplier: int
    max_multiplier: int
    broadcast_min_reward: int
    big_win_min_multiplier: int
    payout_pool_safe_ratio_basis_points: int
    max_daily_spend: int
    max_daily_loss: int
    whale_daily_spend: int
    whale_single_spend: int
    whale_recent_count: int
    whale_recent_window_minutes: int
    manual_review_score: int
    block_score: int
    multipliers: list[LuckyGiftMultiplierRule]


class LuckyGiftPoolPairResponse(BaseModel):
    main_pool: GamePoolResponse
    lucky_pool: GamePoolResponse


class LuckyGiftModerationTransaction(BaseModel):
    transaction_id: int
    sender_user_id: int
    receiver_user_id: int | None
    room_id: int | None
    gift_id: str
    gift_name: str | None
    spent_coins: int
    multiplier: int
    reward_coins: int
    net_win_coins: int
    is_big_win: int
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime | None


class LuckyGiftModerationResponse(BaseModel):
    props: LuckyGiftPropsResponse
    house_pools: LuckyGiftPoolPairResponse
    latest_transactions: list[LuckyGiftModerationTransaction]
    high_risk_transactions: list[LuckyGiftModerationTransaction]


class LuckyGiftPoolAdjustRequest(BaseModel):
    game_key: str = Field(default="lucky_gifts", min_length=2, max_length=80)
    pool_type: str = Field(default="GAME_HOUSE_POOL", min_length=3, max_length=80)
    direction: str = Field(..., pattern="^(CREDIT|DEBIT)$")
    amount: int = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=255)


class LuckyGiftPoolTransferRequest(BaseModel):
    amount: int = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=255)


class LuckyGiftPoolSettingsRequest(BaseModel):
    game_key: str = Field(default="lucky_gifts", min_length=2, max_length=80)
    pool_type: str = Field(default="GAME_HOUSE_POOL", min_length=3, max_length=80)
    status: str | None = Field(default=None, pattern="^(ACTIVE|FROZEN|CLOSED)$")
    daily_payout_cap: int | None = Field(default=None, ge=0)
    daily_loss_limit: int | None = Field(default=None, ge=0)
    max_single_payout: int | None = Field(default=None, ge=0)
    rtp_target_basis_points: int | None = Field(default=None, ge=0, le=10000)
    reason: str = Field(..., min_length=3, max_length=255)
