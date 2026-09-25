"""Canonical Kafka topic catalogue and provisioning helper."""

from __future__ import annotations

from dataclasses import dataclass

from aiokafka.admin import AIOKafkaAdminClient, NewTopic
from aiokafka.errors import TopicAlreadyExistsError

from config import Settings


@dataclass(frozen=True)
class TopicSpec:
    family: str
    name: str
    partitions: int
    retention_ms: int
    cleanup_policy: str = "delete"


TOPICS: tuple[TopicSpec, ...] = (
    TopicSpec("user.activity", "funkey.user.activity.v1", 24, 30 * 86400 * 1000),
    TopicSpec("room.events", "funkey.room.events.v1", 48, 30 * 86400 * 1000),
    TopicSpec("vibes.engagement", "funkey.vibes.engagement.v1", 24, 90 * 86400 * 1000),
    TopicSpec("economy.analytics", "funkey.economy.analytics.v1", 24, 365 * 86400 * 1000),
    TopicSpec("game.events", "funkey.game.events.v1", 48, 90 * 86400 * 1000),
    TopicSpec("media.events", "funkey.media.events.v1", 24, 30 * 86400 * 1000),
    TopicSpec("recommendation.events", "funkey.recommendation.events.v1", 24, 30 * 86400 * 1000),
    TopicSpec("analytics.dlq", "funkey.analytics.dlq.v1", 12, 30 * 86400 * 1000),
)

TOPIC_BY_FAMILY = {spec.family: spec.name for spec in TOPICS}


def topic_for_family(family: str) -> str:
    try:
        return TOPIC_BY_FAMILY[family]
    except KeyError as exc:
        raise ValueError(f"unsupported Kafka topic family: {family}") from exc


async def provision_topics(settings: Settings) -> None:
    """Create approved topics; runtime producers never auto-create topics."""
    kwargs = settings.kafka_client_kwargs()
    client = AIOKafkaAdminClient(**kwargs)
    await client.start()
    try:
        existing = set(await client.list_topics())
        pending = [
            NewTopic(
                name=spec.name,
                num_partitions=spec.partitions,
                replication_factor=settings.topic_replication_factor,
                topic_configs={
                    "cleanup.policy": spec.cleanup_policy,
                    "retention.ms": str(spec.retention_ms),
                    "min.insync.replicas": "1" if settings.topic_replication_factor == 1 else "2",
                },
            )
            for spec in TOPICS
            if spec.name not in existing
        ]
        if pending:
            try:
                await client.create_topics(pending, validate_only=False)
            except TopicAlreadyExistsError:
                pass
    finally:
        await client.close()
