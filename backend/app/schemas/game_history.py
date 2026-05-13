from pydantic import BaseModel, Field


class GameRoundHistoryItemResponse(BaseModel):
    round_id: int
    winning_target_id: int
    label: str
    emoji: str | None = None
    multiplier: int
    completed_at: str | None = None


class GameRoundHistoryResponse(BaseModel):
    items: list[GameRoundHistoryItemResponse] = Field(default_factory=list)
