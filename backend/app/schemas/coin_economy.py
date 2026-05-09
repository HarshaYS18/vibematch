from datetime import datetime
from pydantic import BaseModel, Field

from app.models.coin_economy import CoinBalanceType, CoinTransactionStatus, CoinTransactionType


class CoinGrantRequest(BaseModel):
    target_public_user_id: int
    amount: int = Field(gt=0)
    target_balance_type: CoinBalanceType
    reason: str = Field(min_length=1, max_length=500)


class CoinSendToUserRequest(BaseModel):
    target_public_user_id: int
    amount: int = Field(gt=0)
    reason: str = Field(default="Coin send to user", max_length=500)


class CoinConsumeRequest(BaseModel):
    amount: int = Field(gt=0)
    reason: str = Field(default="User consumption", max_length=500)


class CoinBalanceResponse(BaseModel):
    user_id: int
    public_user_id: int
    display_name: str | None = None
    balance_type: CoinBalanceType
    amount: int
    is_locked: bool


class CoinWalletResponse(BaseModel):
    user_id: int
    public_user_id: int
    display_name: str | None = None
    balances: list[CoinBalanceResponse]


class CoinTransactionResponse(BaseModel):
    id: int
    transaction_public_id: str
    transaction_type: CoinTransactionType
    status: CoinTransactionStatus
    from_user_id: int | None
    to_user_id: int | None
    from_balance_type: CoinBalanceType | None
    to_balance_type: CoinBalanceType | None
    amount: int
    actor_user_id: int | None
    reason: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class CoinActionResponse(BaseModel):
    ok: bool = True
    message: str
    transaction: CoinTransactionResponse
    actor_wallet: CoinWalletResponse | None = None
    target_wallet: CoinWalletResponse | None = None
