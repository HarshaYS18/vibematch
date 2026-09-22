"""Versioned event envelope shared by the outbox relay and job consumer."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class EventEnvelope(BaseModel):
    event_id: UUID
    event_type: str = Field(pattern=r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$", max_length=100)
    event_version: int = Field(ge=1, le=1)
    occurred_at: datetime
    request_id: str | None = Field(default=None, max_length=64)
    trace_id: str | None = Field(default=None, max_length=64)
    actor_user_id: int | None = None
    payload: dict[str, Any]

    @field_validator("occurred_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("occurred_at must include a timezone")
        return value

    @property
    def subject(self) -> str:
        return f"funkey.events.{self.event_type}"
