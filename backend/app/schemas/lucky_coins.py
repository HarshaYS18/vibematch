from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class LuckyCoinWagerRequest(BaseModel):
    request_id: str | None = Field(default=None, min_length=8, max_length=80)
    gift_id: str | None = Field(default=None, max_length=80)
    room_public_id: str | None = None
    receiver_public_user_id: int | None = None
    quantity: int = Field(default=1, gt=0, le=999)
    coin_value: int = Field(default=0, ge=0)
    wager_amount: int = Field(..., gt=0)
    metadata: dict[str, Any] = Field(default_factory=dict)


class LuckyCoinWagerResponse(BaseModel):
    reference_id: str
    user_id: int
    gift_id: str | None = None
    room_public_id: str | None = None
    receiver_public_user_id: int | None = None
    wager_amount: int
    wallet_coin_balance: int
    house_reservation: dict[str, Any] = Field(default_factory=dict)
    rule: str


class LuckyCoinSettleRequest(BaseModel):
    reference_id: str
    request_id: str | None = Field(default=None, min_length=8, max_length=80)
    gift_id: str | None = Field(default=None, max_length=80)
    room_public_id: str | None = None
    receiver_public_user_id: int | None = None
    quantity: int = Field(default=1, gt=0, le=999)
    coin_value: int = Field(default=0, ge=0)
    wager_amount: int = Field(default=0, ge=0)
    reward_amount: int = Field(default=0, ge=0)
    multiplier: int = Field(default=0, ge=0)
    net_win_coins: int = 0
    metadata: dict[str, Any] = Field(default_factory=dict)


class LuckyCoinSettleResponse(BaseModel):
    reference_id: str
    user_id: int
    gift_id: str | None = None
    room_public_id: str | None = None
    receiver_public_user_id: int | None = None
    wager_amount: int
    reward_amount: int
    multiplier: int
    net_win_coins: int
    wallet_coin_balance: int
    house_profit_or_loss: int = 0
    rule: str


class LuckyGiftPayoutToWalletRequest(BaseModel):
    gift_id: str = Field(..., min_length=1, max_length=80)
    room_public_id: str | None = None
    receiver_public_user_id: int | None = None
    quantity: int = Field(default=1, gt=0, le=999)
    coin_value: int = Field(..., gt=0)
    reward_amount: int = Field(default=0, ge=0)
    multiplier: int = Field(default=0, ge=0)
    metadata: dict[str, Any] = Field(default_factory=dict)


class LuckyGiftPayoutToWalletResponse(BaseModel):
    gift_id: str
    room_public_id: str | None = None
    receiver_public_user_id: int | None = None
    quantity: int
    coin_value: int
    wager_amount: int
    reward_amount: int
    multiplier: int
    net_win_coins: int
    wallet_coin_balance: int
    reference_id: str
    metadata: dict[str, Any] = Field(default_factory=dict)
