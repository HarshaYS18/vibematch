from pydantic import BaseModel, Field


class JungleHuntTargetWeight(BaseModel):
    target_id: int = Field(..., ge=0, le=7)
    label: str
    multiplier: int
    weight: int = Field(..., ge=0, le=1_000_000)


class JungleHuntPropsResponse(BaseModel):
    game_key: str
    testing_mode_enabled: bool

    round_seconds: int
    lock_seconds: int
    reveal_seconds: int
    result_seconds: int
    close_betting_last_seconds: int

    max_total_bet_per_round: int
    max_targets_per_user_round: int
    max_round_liability: int
    max_target_liability: int

    max_daily_loss: int
    max_daily_bet_volume: int
    whale_daily_volume: int
    whale_single_bet: int
    whale_recent_bet_count: int

    rare_basket_probability_basis_points: int
    left_basket_weight: int
    right_basket_weight: int
    target_weights: list[JungleHuntTargetWeight]


class LuckyGiftMultiplierWeight(BaseModel):
    multiplier: int = Field(..., ge=0, le=1000)
    weight: int = Field(..., ge=0, le=1_000_000)
    difficulty: str = Field(default="normal", max_length=40)


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

    multipliers: list[LuckyGiftMultiplierWeight]


class LuckyGiftHousePoolResponse(BaseModel):
    game_key: str
    pool_type: str
    house_pool_balance: int
    house_reserved_liability: int
    house_exposure: int
    max_payout_per_round: int
    daily_house_loss_limit: int
    risk_tier: str
    payout_pressure: float
    rtp_target_basis_points: int
    status: str


class LuckyGiftHousePoolUpdateRequest(BaseModel):
    request_id: str | None = Field(default=None, min_length=8, max_length=160)
    balance: int | None = Field(default=None, ge=0)
    reserved_balance: int | None = Field(default=None, ge=0)
    max_payout_per_round: int | None = Field(default=None, ge=0)
    daily_house_loss_limit: int | None = Field(default=None, ge=0)
    rtp_target_basis_points: int | None = Field(default=None, ge=0, le=10000)
    status: str | None = Field(default=None, max_length=20)
    reason: str = Field(..., min_length=3, max_length=255)
