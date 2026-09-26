from datetime import datetime

from pydantic import BaseModel, Field


class GamePoolResponse(BaseModel):
    id: int
    game_key: str
    pool_type: str
    balance: int
    reserved_balance: int
    available_balance: int
    status: str
    daily_payout_cap: int
    daily_loss_limit: int
    max_single_payout: int
    rtp_target_basis_points: int
    created_at: datetime
    updated_at: datetime


class GamePoolPairResponse(BaseModel):
    main_pool: GamePoolResponse
    game_pool: GamePoolResponse


class GamePoolAdjustRequest(BaseModel):
    request_id: str | None = Field(default=None, min_length=8, max_length=80)
    game_key: str = Field(default="jackpot_king", min_length=2, max_length=80)
    pool_type: str = Field(default="GAME_HOUSE_POOL", min_length=3, max_length=80)
    direction: str = Field(..., pattern="^(CREDIT|DEBIT)$")
    amount: int = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=255)


class GamePoolTransferRequest(BaseModel):
    request_id: str | None = Field(default=None, min_length=8, max_length=80)
    game_key: str = Field(default="jackpot_king", min_length=2, max_length=80)
    amount: int = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=255)


class GamePoolSettingsRequest(BaseModel):
    request_id: str | None = Field(default=None, min_length=8, max_length=80)
    game_key: str = Field(default="jackpot_king", min_length=2, max_length=80)
    pool_type: str = Field(default="GAME_HOUSE_POOL", min_length=3, max_length=80)
    status: str | None = Field(default=None, pattern="^(ACTIVE|FROZEN|CLOSED)$")
    daily_payout_cap: int | None = Field(default=None, ge=0)
    daily_loss_limit: int | None = Field(default=None, ge=0)
    max_single_payout: int | None = Field(default=None, ge=0)
    rtp_target_basis_points: int | None = Field(default=None, ge=0, le=10000)
    reason: str = Field(..., min_length=3, max_length=255)
