"""NATS JetStream -> Kafka bridge with at-least-once source semantics."""

from __future__ import annotations

import asyncio
import json
import random
from time import perf_counter
from typing import Any

from pydantic import ValidationError

from contracts import OperationalEventEnvelope, build_kafka_envelope
from metrics import count, observe_publish, set_in_flight
from topics import topic_for_family


def kafka_headers(envelope) -> list[tuple[str, bytes]]:
    headers = [
        ("event_id", str(envelope.event_id).encode()),
        ("event_type", envelope.event_type.encode()),
        ("schema_version", str(envelope.schema_version).encode()),
    ]
    if envelope.trace_id:
        headers.append(("trace_id", envelope.trace_id.encode()))
    if envelope.request_id:
        headers.append(("x-request-id", envelope.request_id.encode()))
    return headers


async def publish_to_kafka(producer: Any, envelope) -> None:
    topic = topic_for_family(envelope.topic_family)
    started = perf_counter()
    await producer.send_and_wait(
        topic,
        envelope.model_dump_json().encode(),
        key=envelope.partition_key.encode(),
        headers=kafka_headers(envelope),
    )
    observe_publish(envelope.topic_family, perf_counter() - started)


async def dead_letter_invalid(js: Any, msg: Any, reason: str) -> None:
    """Durably quarantine poison source data in NATS before acknowledging it."""
    body = json.dumps(
        {
            "source_subject": msg.subject,
            "reason": reason,
            "bridge": "kafka-analytics-v1",
        },
        separators=(",", ":"),
    ).encode()
    await js.publish("funkey.dlq.kafka_bridge.invalid", body, timeout=3)
    await msg.ack()
    count("dead_lettered")


async def process_message(js: Any, producer: Any, msg: Any, *, nak_delay_seconds: float) -> None:
    set_in_flight(1)
    family = "all"
    try:
        try:
            event = OperationalEventEnvelope.model_validate_json(msg.data)
            envelope = build_kafka_envelope(event)
        except (ValidationError, ValueError) as exc:
            await dead_letter_invalid(js, msg, type(exc).__name__)
            return

        if envelope is None:
            await msg.ack()
            count("filtered")
            return

        family = envelope.topic_family
        count("received", family)
        try:
            await publish_to_kafka(producer, envelope)
        except asyncio.CancelledError:
            raise
        except Exception:
            count("publish_failed", family)
            jittered = min(60.0, max(0.5, nak_delay_seconds) + random.random())
            await msg.nak(delay=jittered)
            return

        await msg.ack()
        count("published", family)
    finally:
        set_in_flight(-1)


async def consume_loop(
    js: Any,
    subscription: Any,
    producer: Any,
    stop: asyncio.Event,
    *,
    batch_size: int,
    max_in_flight: int,
    nak_delay_seconds: float,
) -> None:
    """Pull with bounded concurrency; source ack occurs only after Kafka ack."""
    slots = asyncio.Semaphore(max_in_flight)
    while not stop.is_set():
        try:
            messages = await subscription.fetch(batch=batch_size, timeout=2)
        except asyncio.TimeoutError:
            continue
        except Exception as exc:
            if type(exc).__name__ in {"TimeoutError", "NatsTimeoutError"}:
                continue
            await asyncio.sleep(1.0)
            continue

        async def one(msg: Any) -> None:
            async with slots:
                await process_message(
                    js,
                    producer,
                    msg,
                    nak_delay_seconds=nak_delay_seconds,
                )

        await asyncio.gather(*(one(msg) for msg in messages if not stop.is_set()))
