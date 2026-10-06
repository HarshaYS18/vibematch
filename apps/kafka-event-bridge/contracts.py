"""Versioned analytics event contract and deterministic routing rules."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


FORBIDDEN_PAYLOAD_KEYS = frozenset({
    "password", "password_hash", "token", "access_token", "refresh_token",
    "id_token", "authorization", "secret", "client_secret", "otp", "cvv",
    "card_number", "session_cookie", "set_cookie",
})


class OperationalEventEnvelope(BaseModel):
    """Current durable NATS event emitted from the transactional outbox."""

    model_config = ConfigDict(extra="forbid")

    event_id: UUID
    event_type: str = Field(pattern=r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$", max_length=100)
    event_version: int = Field(ge=1)
    occurred_at: datetime
    request_id: str | None = Field(default=None, max_length=64)
    trace_id: str | None = Field(default=None, max_length=64)
    traceparent: str | None = Field(default=None, max_length=255)
    actor_user_id: int | None = None
    payload: dict[str, Any]

    @field_validator("occurred_at")
    @classmethod
    def timezone_required(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("occurred_at must include a timezone")
        return value


class ReplayMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    replay_id: str
    source_topic: str
    source_partition: int
    source_offset: int


class KafkaAnalyticsEnvelope(BaseModel):
    """Long-retained Kafka envelope. It never becomes business authority."""

    model_config = ConfigDict(extra="forbid")

    event_id: UUID
    event_type: str
    event_version: int
    schema_version: int = Field(default=1, ge=1, le=1)
    occurred_at: datetime
    published_at: datetime
    producer: str = "nats-jetstream-bridge"
    source_service: str
    topic_family: str
    partition_key: str
    request_id: str | None = None
    trace_id: str | None = None
    correlation_id: str | None = None
    causation_id: str | None = None
    actor_user_id: int | None = None
    replay: ReplayMetadata | None = None
    payload: dict[str, Any]


_TOPIC_RULES: tuple[tuple[tuple[str, ...], str], ...] = (
    (("room.",), "room.events"),
    (("vibes.",), "vibes.engagement"),
    (("economy.", "wallet.", "gift.", "purchase.", "payment."), "economy.analytics"),
    (("game.", "cricket."), "game.events"),
    (("media.",), "media.events"),
    (("recommendation.", "discovery."), "recommendation.events"),
    (("user.", "identity.", "profile.", "social.", "auth."), "user.activity"),
)


def topic_family_for(event_type: str) -> str | None:
    normalized = (event_type or "").strip().lower()
    for prefixes, family in _TOPIC_RULES:
        if normalized.startswith(prefixes):
            return family
    return None


def source_service_for(event_type: str) -> str:
    prefix = (event_type or "unknown").split(".", 1)[0].strip().lower()
    return prefix or "unknown"


def _candidate(payload: dict[str, Any], names: tuple[str, ...]) -> str | None:
    for name in names:
        value = payload.get(name)
        if value is not None and str(value).strip():
            return str(value).strip()
    return None


def partition_key_for(event: OperationalEventEnvelope, family: str) -> str:
    payload = event.payload
    names = {
        "room.events": ("room_public_id", "room_id", "public_room_id"),
        "user.activity": ("public_user_id", "user_id", "target_user_id"),
        "vibes.engagement": ("post_id", "vibe_id", "public_user_id", "user_id"),
        "economy.analytics": ("wallet_id", "transaction_id", "public_user_id", "user_id"),
        "game.events": ("game_session_id", "session_id", "round_id", "room_public_id"),
        "media.events": ("media_id", "upload_id", "asset_id", "public_user_id"),
        "recommendation.events": ("public_user_id", "user_id", "room_public_id"),
    }.get(family, ())
    candidate = _candidate(payload, names)
    if candidate:
        return candidate
    if event.actor_user_id is not None:
        return str(event.actor_user_id)
    return str(event.event_id)


def sensitive_payload_paths(payload: Any, prefix: str = "payload") -> list[str]:
    found: list[str] = []
    if isinstance(payload, dict):
        for key, value in payload.items():
            normalized = str(key).lower().replace("-", "_")
            path = f"{prefix}.{key}"
            if normalized in FORBIDDEN_PAYLOAD_KEYS or normalized.endswith("_password"):
                found.append(path)
            found.extend(sensitive_payload_paths(value, path))
    elif isinstance(payload, list):
        for index, value in enumerate(payload):
            found.extend(sensitive_payload_paths(value, f"{prefix}[{index}]"))
    return found


def build_kafka_envelope(event: OperationalEventEnvelope) -> KafkaAnalyticsEnvelope | None:
    family = topic_family_for(event.event_type)
    if family is None:
        return None
    sensitive = sensitive_payload_paths(event.payload)
    if sensitive:
        raise ValueError("sensitive payload keys are forbidden in Kafka analytics events")
    return KafkaAnalyticsEnvelope(
        event_id=event.event_id,
        event_type=event.event_type,
        event_version=event.event_version,
        occurred_at=event.occurred_at,
        published_at=datetime.now(timezone.utc),
        source_service=source_service_for(event.event_type),
        topic_family=family,
        partition_key=partition_key_for(event, family),
        request_id=event.request_id,
        trace_id=event.trace_id,
        actor_user_id=event.actor_user_id,
        payload=event.payload,
    )
