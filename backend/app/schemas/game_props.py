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
