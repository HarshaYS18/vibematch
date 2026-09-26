"""Reusable Kafka projection-consumer framework.

The framework commits offsets only after a handler reports success. Projection
sinks must use event_id as their durable idempotency key; Kafka is not business
authority and duplicate delivery is expected.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
from dataclasses import dataclass
from typing import Awaitable, Callable, Protocol

from aiokafka import AIOKafkaConsumer, AIOKafkaProducer, TopicPartition
from aiokafka.structs import OffsetAndMetadata
from pydantic import ValidationError

from config import Settings
from contracts import KafkaAnalyticsEnvelope
from topics import topic_for_family


class ProjectionSink(Protocol):
    async def __call__(self, event: KafkaAnalyticsEnvelope) -> None: ...


@dataclass(frozen=True)
class ConsumerSpec:
    family: str
    group_id: str
    auto_offset_reset: str = "earliest"


def build_dlq_value(
    *,
    source_topic: str,
    partition: int,
    offset: int,
    reason: str,
    raw_value: bytes,
) -> bytes:
    return json.dumps(
        {
            "source_topic": source_topic,
            "source_partition": partition,
            "source_offset": offset,
            "reason": reason,
            "raw_sha256": hashlib.sha256(raw_value).hexdigest(),
            "raw_bytes": len(raw_value),
        },
        separators=(",", ":"),
    ).encode()


async def run_projection_consumer(
    settings: Settings,
    spec: ConsumerSpec,
    sink: ProjectionSink,
    stop: asyncio.Event,
) -> None:
    topic = topic_for_family(spec.family)
    common = settings.kafka_client_kwargs()
    consumer = AIOKafkaConsumer(
        topic,
        **common,
        group_id=spec.group_id,
        enable_auto_commit=False,
        auto_offset_reset=spec.auto_offset_reset,
        max_poll_records=100,
    )
    producer = AIOKafkaProducer(
        **common,
        acks="all",
        enable_idempotence=True,
    )
    await consumer.start()
    await producer.start()
    try:
        while not stop.is_set():
            batch = await consumer.getmany(timeout_ms=1000, max_records=100)
            if not batch:
                continue
            for _tp, messages in batch.items():
                for message in messages:
                    try:
                        event = KafkaAnalyticsEnvelope.model_validate_json(message.value)
                        await sink(event)
                    except (ValidationError, ValueError) as exc:
                        await producer.send_and_wait(
                            "funkey.analytics.dlq.v1",
                            build_dlq_value(
                                source_topic=message.topic,
                                partition=message.partition,
                                offset=message.offset,
                                reason=type(exc).__name__,
                                raw_value=message.value,
                            ),
                            key=str(message.offset).encode(),
                        )
                    await consumer.commit({
                        TopicPartition(message.topic, message.partition):
                            OffsetAndMetadata(message.offset + 1, "")
                    })
    finally:
        await consumer.stop()
        await producer.stop()
