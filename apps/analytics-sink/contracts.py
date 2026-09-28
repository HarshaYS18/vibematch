"""Validated projection-only analytics event envelope."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class AnalyticsEvent(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_id: UUID
    event_type: str = Field(min_length=1, max_length=160)
    event_version: int = Field(ge=1)
    schema_version: int = Field(ge=1)
    occurred_at: datetime
    published_at: datetime
    source_service: str = Field(min_length=1, max_length=80)
    topic_family: str = Field(min_length=1, max_length=80)
    partition_key: str = Field(min_length=1, max_length=256)
    actor_user_id: int | None = None
    traceparent: str | None = Field(default=None, max_length=256)
    payload: dict[str, Any]

    @field_validator("occurred_at", "published_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("analytics timestamps must be timezone-aware")
        return value

    def row(self) -> dict[str, object]:
        import json
        return {
            "event_id": str(self.event_id),
            "event_type": self.event_type,
            "event_version": self.event_version,
            "schema_version": self.schema_version,
            "occurred_at": self.occurred_at.isoformat(),
            "published_at": self.published_at.isoformat(),
            "source_service": self.source_service,
            "topic_family": self.topic_family,
            "partition_key": self.partition_key,
            "actor_user_id": self.actor_user_id,
            "traceparent": self.traceparent,
            "payload_json": json.dumps(self.payload, separators=(",", ":"), sort_keys=True),
        }
