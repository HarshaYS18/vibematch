"""Kafka -> recommendation feature/feed projection consumer."""

from __future__ import annotations

import asyncio

from aiokafka import AIOKafkaConsumer, TopicPartition
from aiokafka.structs import OffsetAndMetadata
from pydantic import ValidationError

from config import Settings
from contracts import KafkaEvent, signal_from_event
from store import RecommendationStore


TOPICS = (
    "funkey.user.activity.v1",
    "funkey.room.events.v1",
    "funkey.vibes.engagement.v1",
    "funkey.game.events.v1",
    "funkey.recommendation.events.v1",
)


async def run_consumer(
    settings: Settings,
    store: RecommendationStore,
    stop: asyncio.Event,
) -> None:
    consumer = AIOKafkaConsumer(
        *TOPICS,
        **settings.kafka_kwargs(),
        group_id=settings.group_id,
        enable_auto_commit=False,
        auto_offset_reset="earliest",
        max_poll_records=200,
    )
    await consumer.start()
    try:
        while not stop.is_set():
            batch = await consumer.getmany(timeout_ms=1000, max_records=200)
            for _tp, messages in batch.items():
                for message in messages:
                    try:
                        event = KafkaEvent.model_validate_json(message.value)
                        signal = signal_from_event(event)
                        if signal is not None:
                            await store.apply(signal)
                    except (ValidationError, ValueError):
                        # Poison analytical events must not block the entire group.
                        # Kafka platform DLQ/replay tooling retains provenance.
                        pass
                    await consumer.commit(
                        {
                            TopicPartition(message.topic, message.partition):
                            OffsetAndMetadata(message.offset + 1, "")
                        }
                    )
    finally:
        await consumer.stop()
