from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, model_validator


class EconomyWalletResponse(BaseModel):
    user_id: int
    coin_balance: int
    ruby_balance: int
    withdrawable_rubies: int
    pending_withdraw_rubies: int
    lifetime_coins_spent: int
    lifetime_coins_received_as_gifts: int = 0
    lifetime_rubies_earned: int
    lifetime_recharge_coin_exp: int = 0
    monthly_recharge_coin_exp: int = 0
    monthly_gift_coins_sent: int = 0
    monthly_gift_coins_received: int = 0
    lifetime_send_exp: int = 0
    lifetime_receive_exp: int = 0
    vip: dict[str, Any] = Field(default_factory=dict)
    svip: dict[str, Any] = Field(default_factory=dict)
    sent: dict[str, Any] = Field(default_factory=dict)
    received: dict[str, Any] = Field(default_factory=dict)


class EconomyPoolResponse(BaseModel):
    id: int
    owner_user_id: int | None
    pool_type: str
    balance: int
    reserved_balance: int
    status: str


class EconomyDashboardResponse(BaseModel):
    wallet: EconomyWalletResponse
    seller_pool: EconomyPoolResponse | None = None
    merchant_pool: EconomyPoolResponse | None = None
    gaming_pool: EconomyPoolResponse | None = None
    note: str = "Supply pool coins are inventory only and never appear in normal coin balance."


class MintCoinsRequest(BaseModel):
    target_pool_type: str = Field(..., min_length=3)
    target_user_id: int | None = None
    amount: int = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=255)


class InternalWalletGrantRequest(BaseModel):
    target_user_id: int
    coin_amount: int = Field(..., gt=0, le=100_000_000)
    reason: str = Field(..., min_length=3, max_length=255)


class OfficialRechargeRequest(BaseModel):
    target_user_id: int | None = None
    target_public_user_id: int | None = None
    coin_amount: int = Field(..., gt=0)
    payment_amount: int = Field(default=0, ge=0)
    payment_currency: str = "INR"
    reason: str = Field(..., min_length=3, max_length=255)
    proof_url: str | None = None


class OfficialRechargeResponse(BaseModel):
    order_id: int | None = None
    target_user_id: int
    target_public_user_id: int | None = None
    coin_amount: int
    payment_amount: int
    payment_currency: str
    wallet: EconomyWalletResponse
    rule: str


class AllocatePoolCoinsRequest(BaseModel):
    source_pool_id: int
    target_pool_type: str
    target_user_id: int | None = None
    amount: int = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=255)


class SellerSaleRequest(BaseModel):
    buyer_user_id: int
    source_pool_id: int
    coin_amount: int = Field(..., gt=0)
    payment_amount: int = Field(default=0, ge=0)
    payment_currency: str = "INR"
    proof_url: str | None = None


class GiftEconomyPreviewRequest(BaseModel):
    receiver_user_id: int
    gift_id: str
    coin_value: int = Field(..., gt=0)
    quantity: int = Field(default=1, gt=0)
    room_id: int | None = None
    relationship_id: int | None = None
    is_relationship_gift: bool = False


class GiftEconomyPreviewResponse(BaseModel):
    total_coin_value: int
    receiver_ruby_amount: int
    platform_share_coin_value: int
    send_exp_amount: int
    receive_exp_amount: int
    room_exp_amount: int
    love_score_amount: int
    rule: str


class GiftSendRequest(BaseModel):
    receiver_user_id: int
    gift_id: str = Field(..., min_length=1, max_length=80)
    coin_value: int = Field(..., gt=0)
    quantity: int = Field(default=1, gt=0)
    room_id: int | None = None
    relationship_id: int | None = None
    is_relationship_gift: bool = False


class GiftSendPublicRequest(BaseModel):
    receiver_public_user_id: int
    gift_id: str = Field(..., min_length=1, max_length=80)
    coin_value: int = Field(..., gt=0)
    quantity: int = Field(default=1, gt=0)
    room_public_id: str | None = None
    relationship_id: int | None = None
    is_relationship_gift: bool = False


class GiftSendResponse(BaseModel):
    gift_transaction_id: int
    sender_user_id: int
    receiver_user_id: int
    total_coin_value: int
    receiver_ruby_amount: int
    platform_share_coin_value: int
    send_exp_amount: int
    receive_exp_amount: int
    room_exp_amount: int
    love_score_amount: int
    sender_coin_balance: int
    receiver_ruby_balance: int
    receiver_lifetime_gift_coin_value: int = 0
    receiver_lifetime_rubies_earned: int = 0
    experience_updates: dict[str, Any] = Field(default_factory=dict)
    ruby_rule: str | None = None
    rule: str
    spent_coins: int | None = None
    reward_coins: int | None = None
    spent_coin_amount: int | None = None
    reward_coin_amount: int | None = None
    net_win_coins: int | None = None
    winner_coin_balance: int | None = None
    wallet_coin_balance: int | None = None
    lucky_gift_transaction_id: int | None = None
    lucky_multiplier: int | None = None
    lucky_reward_coin_amount: int | None = None
    lucky_result: dict[str, Any] | None = None
    lucky_difficulty: str | None = None
    risk_level: str | None = None
    risk_score: int | None = None
    risk_action: str | None = None

    @model_validator(mode="after")
    def normalize_lucky_aliases(self):
        if self.spent_coin_amount is None and self.spent_coins is not None:
            self.spent_coin_amount = self.spent_coins
        if self.reward_coin_amount is None and self.reward_coins is not None:
            self.reward_coin_amount = self.reward_coins
        if self.reward_coin_amount is None and self.lucky_reward_coin_amount is not None:
            self.reward_coin_amount = self.lucky_reward_coin_amount
        return self


class RubyConversionRequest(BaseModel):
    ruby_amount: int = Field(..., gt=0)


class RubyWithdrawRequestCreate(BaseModel):
    ruby_amount: int = Field(..., gt=0)
    payout_method: str | None = None
    payout_account_snapshot: str | None = None


class GamePoolCreateRequest(BaseModel):
    game_key: str = Field(..., min_length=2, max_length=80)
    pool_type: str
    opening_balance: int = Field(default=0, ge=0)
    daily_payout_cap: int = Field(default=0, ge=0)
    daily_loss_limit: int = Field(default=0, ge=0)
    max_single_payout: int = Field(default=0, ge=0)
    rtp_target_basis_points: int = Field(default=8000, ge=0, le=10000)


class GameRoundCreateRequest(BaseModel):
    game_key: str
    entry_fee: int = Field(..., ge=0)
    max_players: int = Field(default=4, gt=0)
    room_id: int | None = None


class EconomyLedgerEntryResponse(BaseModel):
    id: int
    direction: str
    amount: int
    before_balance: int
    after_balance: int
    source_type: str
    reason: str | None
    created_at: datetime
