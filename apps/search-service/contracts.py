"""Search projection contract.

Domain services remain authoritative. Search consumes versioned events and stores
only disposable documents in OpenSearch.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


SearchKind = Literal["user", "room", "vibe"]


class EventEnvelope(BaseModel):
    model_config = ConfigDict(extra="allow")

    event_id: UUID
    event_type: str
    event_version: int = Field(ge=1)
    occurred_at: datetime
    payload: dict[str, Any]

    @field_validator("occurred_at")
    @classmethod
    def tz_required(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("occurred_at must be timezone-aware")
        return value


class SearchDocument(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kind: SearchKind
    public_id: str = Field(min_length=1, max_length=128)
    title: str = Field(min_length=1, max_length=256)
    subtitle: str = Field(default="", max_length=512)
    tags: list[str] = Field(default_factory=list, max_length=32)
    keywords: list[str] = Field(default_factory=list, max_length=64)
    image_url: str | None = Field(default=None, max_length=2048)
    language: str | None = Field(default=None, max_length=32)
    popularity: float = Field(default=0.0, ge=0.0)
    updated_at: datetime
    deleted: bool = False


def projection_from_event(event: EventEnvelope) -> SearchDocument | None:
    raw = event.payload.get("search_projection")
    if raw is None:
        return None
    if not isinstance(raw, dict):
        raise ValueError("search_projection must be an object")
    return SearchDocument.model_validate(raw)
