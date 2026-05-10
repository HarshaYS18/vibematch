from typing import Any

from pydantic import BaseModel, Field


class GameTargetConfig(BaseModel):
    id: int
    label: str
    emoji: str | None = None
    icon_url: str | None = None
    multiplier: int
    theme_color: str | None = None


class GameRulesConfig(BaseModel):
    round_seconds: int = 24
    lock_seconds: int = 1
    result_seconds: int = 5
    allowed_bets: list[int] = Field(default_factory=lambda: [400, 10_000, 100_000])
    custom_bet_enabled: bool = True
    min_bet: int = 100
    max_bet: int = 100_000
    max_total_bet_per_round: int = 300_000
    targets: list[GameTargetConfig] = Field(default_factory=list)


class GameRiskConfig(BaseModel):
    enabled: bool = True
    max_daily_loss: int = 500_000
    max_daily_bet_volume: int = 2_000_000
    max_single_bet_low: int = 100_000
    max_single_bet_medium: int = 50_000
    max_single_bet_high: int = 10_000
    force_min_bet_extreme: int = 400
    cooldown_seconds_high_risk: int = 300
    manual_review_score: int = 90
    block_score: int = 120


class GameDefinitionResponse(BaseModel):
    game_key: str
    display_name: str
    category: str
    is_enabled: bool
    is_coin_game: bool
    min_app_version: str
    config_version: int
    cdn_base_url: str | None = None
    config_url: str | None = None
    asset_manifest_url: str | None = None
    ui_config: dict[str, Any]
    rules: dict[str, Any]
    risk: dict[str, Any]


class GameCatalogResponse(BaseModel):
    games: list[GameDefinitionResponse]


class GameAdminUpsertRequest(BaseModel):
    display_name: str
    category: str = "coin"
    is_enabled: bool = False
    is_coin_game: bool = True
    min_app_version: str = "1.0.0"
    config_version: int = 1
    cdn_base_url: str | None = None
    config_url: str | None = None
    asset_manifest_url: str | None = None
    ui_config: dict[str, Any] = Field(default_factory=dict)
    rules: dict[str, Any] = Field(default_factory=dict)
    risk: dict[str, Any] = Field(default_factory=dict)


class GameRoundCreateRequest(BaseModel):
    room_id: int | None = None


class GameRoundResponse(BaseModel):
    id: int
    game_key: str
    room_id: int | None
    status: str
    entry_fee: int
    max_players: int
    round_pool_amount: int
    platform_fee_amount: int
    reward_pool_amount: int
    metadata: dict[str, Any]


class GameBetRequest(BaseModel):
    target_id: int
    amount: int


class GameBetResponse(BaseModel):
    bet_id: int | None = None
    round_id: int
    target_id: int
    requested_amount: int
    accepted_amount: int
    wallet_coin_balance: int
    risk_level: str
    risk_score: int
    risk_action: str
    message: str


class GameRoundResultResponse(BaseModel):
    round_id: int
    game_key: str
    status: str
    winning_target_id: int
    multiplier: int
    total_user_bet: int
    total_user_winnings: int
    wallet_coin_balance: int
    risk_level: str
    risk_score: int
    risk_action: str
    audit_message: str
