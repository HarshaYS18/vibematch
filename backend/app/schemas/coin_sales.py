from pydantic import BaseModel, Field


class CoinSellerSupplyGrantRequest(BaseModel):
    target_public_user_id: int
    pool_type: str = Field(..., min_length=3, max_length=80)
    amount: int = Field(..., gt=0, le=1_000_000_000)
    reason: str = Field(..., min_length=3, max_length=255)


class CoinSellerSellToUserRequest(BaseModel):
    target_public_user_id: int
    coin_amount: int = Field(..., gt=0, le=100_000_000)
    payment_amount: int = Field(default=0, ge=0)
    payment_currency: str = Field(default="INR", min_length=2, max_length=20)
    proof_url: str | None = None
    source_pool_id: int | None = None
    reason: str = Field(default="Coin sale to user", min_length=3, max_length=255)


class CoinSellerPoolResponse(BaseModel):
    id: int
    owner_user_id: int | None
    pool_type: str
    balance: int
    reserved_balance: int
    status: str


class CoinSellerSaleResponse(BaseModel):
    order_id: int
    seller_user_id: int
    buyer_user_id: int
    buyer_public_user_id: int
    source_pool_id: int
    coin_amount: int
    buyer_wallet_coin_balance: int
    seller_pool_balance: int
    delivery_status: str
    note: str
