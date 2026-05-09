from datetime import datetime

from pydantic import BaseModel, Field


class EconomyWalletResponse(BaseModel):
    user_id: int
    coin_balance: int
    ruby_balance: int
    withdrawable_rubies: int
    pending_withdraw_rubies: int
    lifetime_coins_spent: int
    lifetime_rubies_earned: int


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


class RubyConversionRequest(BaseModel):
    ruby_amount: int = Field(..., gt=0)


class RubyWithdrawRequestCreate(BaseModel):
    ruby_amount: int = Field(..., gt=0)
    payout_method: str | None = None
    payout_account_snapshot: str | None = None


class GamePoolCreateRequest(BaseModel):
    game_key: str = Field(..., min_length=2, max_length=80)
    pool_type: str
    owner_user_id: int | None = None
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
