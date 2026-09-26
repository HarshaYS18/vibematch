"""Recommendation signal contracts derived from retained Kafka analytics events."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


CandidateKind = Literal["room", "vibe", "user", "game"]


class KafkaEvent(BaseModel):
    model_config = ConfigDict(extra="allow")

    event_id: UUID
    event_type: str
    event_version: int = Field(ge=1)
    occurred_at: datetime
    actor_user_id: int | None = None
    payload: dict[str, Any]

    @field_validator("occurred_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("occurred_at must be timezone-aware")
        return value


class RecommendationSignal(BaseModel):
    model_config = ConfigDict(extra="forbid")

    public_user_id: str = Field(min_length=1, max_length=128)
    candidate_id: str = Field(min_length=1, max_length=128)
    candidate_kind: CandidateKind
    action: str = Field(min_length=1, max_length=64)
    weight: float = Field(ge=-100.0, le=100.0)
    occurred_at: datetime

    @property
    def member(self) -> str:
        return f"{self.candidate_kind}:{self.candidate_id}"


_DEFAULT_WEIGHTS = {
    "view": 0.5,
    "impression": 0.1,
    "click": 2.0,
    "join": 4.0,
    "like": 3.0,
    "follow": 6.0,
    "share": 5.0,
    "dismiss": -3.0,
    "block": -100.0,
}


def signal_from_event(event: KafkaEvent) -> RecommendationSignal | None:
    raw = event.payload.get("recommendation_signal")
    if raw is not None:
        if not isinstance(raw, dict):
            raise ValueError("recommendation_signal must be an object")
        merged = dict(raw)
        merged.setdefault("occurred_at", event.occurred_at)
        return RecommendationSignal.model_validate(merged)

    public_user_id = event.payload.get("public_user_id")
    candidate_id = event.payload.get("candidate_id")
    candidate_kind = event.payload.get("candidate_kind")
    action = event.payload.get("action")
    if not all((public_user_id, candidate_id, candidate_kind, action)):
        return None
    weight = _DEFAULT_WEIGHTS.get(str(action).lower())
    if weight is None:
        return None
    return RecommendationSignal(
        public_user_id=str(public_user_id),
        candidate_id=str(candidate_id),
        candidate_kind=str(candidate_kind),
        action=str(action),
        weight=weight,
        occurred_at=event.occurred_at,
    )
