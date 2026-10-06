from datetime import datetime

from pydantic import BaseModel, Field


class RoomPkChallengeRequest(BaseModel):
    opponent_room_id: str = Field(min_length=2, max_length=32)
    duration_seconds: int = Field(default=180, ge=60, le=600)


class RoomPkDecisionRequest(BaseModel):
    accept: bool


class RoomPkRoomSummary(BaseModel):
    room_id: str
    room_name: str
    cover_photo_url: str | None = None
    online_count: int = 0


class RoomPkMatchResponse(BaseModel):
    match_id: str
    status: str
    challenger: RoomPkRoomSummary
    opponent: RoomPkRoomSummary
    duration_seconds: int
    challenger_score: int
    opponent_score: int
    winner_room_id: str | None = None
    challenge_expires_at: datetime
    started_at: datetime | None = None
    ends_at: datetime | None = None
    finished_at: datetime | None = None
    finished_reason: str | None = None


class RoomPkGiftScoreRequest(BaseModel):
    room_public_id: str = Field(min_length=2, max_length=32)
    source_event_id: str = Field(min_length=1, max_length=160)
    coin_value: int = Field(ge=1)
