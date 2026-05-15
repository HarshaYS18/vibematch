from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class GameWagerRequest(BaseModel):
    game_id: str = Field(..., min_length=1, max_length=80)
    round_id: str | None = None
    wager_amount: int = Field(..., gt=0)
    metadata: dict[str, Any] = Field(default_factory=dict)


class GameWagerResponse(BaseModel):
    game_id: str
    round_id: str | None = None
    wager_amount: int
    wallet_coin_balance: int
    reference_id: str
    house_reservation: dict[str, Any] = Field(default_factory=dict)
    rule: str


class GameSettleRequest(BaseModel):
    game_id: str = Field(..., min_length=1, max_length=80)
    round_id: str | None = None
    wager_amount: int = Field(default=0, ge=0)
    win_amount: int = Field(default=0, ge=0)
    loss_amount: int = Field(default=0, ge=0)
    net_amount: int = 0
    multiplier: int = Field(default=0, ge=0)
    metadata: dict[str, Any] = Field(default_factory=dict)


class GameSettleResponse(BaseModel):
    game_id: str
    round_id: str | None = None
    wager_amount: int
    win_amount: int
    loss_amount: int
    net_amount: int
    multiplier: int
    wallet_coin_balance: int
    house_profit_or_loss: int
    risk_score: int
    stats: dict[str, Any] = Field(default_factory=dict)
    rule: str


class GameWinningsToWalletRequest(BaseModel):
    game_id: str = Field(..., min_length=1, max_length=80)
    round_id: str | None = None
    win_amount: int = Field(..., ge=0)
    wager_amount: int = Field(default=0, ge=0)
    multiplier: int = Field(default=0, ge=0)
    metadata: dict[str, Any] = Field(default_factory=dict)


class GameWinningsToWalletResponse(BaseModel):
    game_id: str
    round_id: str | None = None
    wager_amount: int
    win_amount: int
    loss_amount: int
    net_amount: int
    multiplier: int
    wallet_coin_balance: int
    house_profit_or_loss: int
    risk_score: int
    rule: str
