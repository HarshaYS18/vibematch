from pydantic import BaseModel, Field


class LuckyPacketCreateRequest(BaseModel):
    request_id: str | None = Field(default=None, min_length=8, max_length=80)
    room_public_id: str = Field(..., min_length=1, max_length=32)
    coin_amount: int = Field(..., gt=0, le=10_000_000)
    winner_count: int = Field(..., ge=1, le=100)
    message: str = Field(default="", max_length=60)


class LuckyPacketClaimResponse(BaseModel):
    packet_id: str
    room_public_id: str
    sender_user_id: str
    sender_name: str
    coin_amount: int
    winner_count: int
    message: str
    phase: str
    remaining_seconds: int
    claims: dict[str, int] = Field(default_factory=dict)
    claimed_count: int
    claimed_coin_amount: int
    refunded_coin_amount: int
    current_user_reward: int | None = None
    sender_coin_balance: int | None = None
    wallet_coin_balance: int | None = None
    created_at: str


class LuckyPacketResponse(LuckyPacketClaimResponse):
    pass
