"""Manual-offset Kafka consumer for projection-only analytics sinks."""

from __future__ import annotations

import asyncio

from aiokafka import AIOKafkaConsumer, TopicPartition
from aiokafka.structs import OffsetAndMetadata
from pydantic import ValidationError

from config import Settings
from contracts import AnalyticsEvent
from sink import AnalyticsSink


TOPICS = (
    "funkey.user.activity.v1",
    "funkey.room.events.v1",
    "funkey.vibes.engagement.v1",
    "funkey.economy.analytics.v1",
    "funkey.game.events.v1",
    "funkey.media.events.v1",
    "funkey.recommendation.events.v1",
)


async def run_consumer(
    settings: Settings,
    sink: AnalyticsSink,
    stop: asyncio.Event,
    counters: dict[str, int],
) -> None:
    consumer = AIOKafkaConsumer(
        *TOPICS,
        **settings.kafka_kwargs(),
        group_id=settings.kafka_group,
        enable_auto_commit=False,
        auto_offset_reset="earliest",
        max_poll_records=250,
    )
    await consumer.start()
    try:
        while not stop.is_set():
            batches = await consumer.getmany(timeout_ms=1000, max_records=250)
            for tp, messages in batches.items():
                if not messages:
                    continue
                valid: list[AnalyticsEvent] = []
                for message in messages:
                    try:
                        valid.append(AnalyticsEvent.model_validate_json(message.value))
                    except (ValidationError, ValueError):
                        counters["invalid"] += 1
                if valid:
                    try:
                        await sink.write_batch(valid)
                    except Exception:
                        counters["sink_failures"] += 1
                        await asyncio.sleep(1)
                        continue
                    counters["written"] += len(valid)

                last_offset = messages[-1].offset + 1
                await consumer.commit(
                    {TopicPartition(tp.topic, tp.partition): OffsetAndMetadata(last_offset, "")}
                )
    finally:
        await consumer.stop()
