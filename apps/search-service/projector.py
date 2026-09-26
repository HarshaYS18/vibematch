"""NATS JetStream -> OpenSearch projector with explicit ACK semantics."""

from __future__ import annotations

import asyncio

from pydantic import ValidationError

from contracts import EventEnvelope, projection_from_event
from opensearch_store import OpenSearchStore


async def process_message(store: OpenSearchStore, msg) -> None:
    try:
        event = EventEnvelope.model_validate_json(msg.data)
        projection = projection_from_event(event)
    except (ValidationError, ValueError):
        await msg.term()
        return

    if projection is None:
        await msg.ack()
        return

    try:
        await store.apply(projection)
    except Exception:
        await msg.nak(delay=5)
        return
    await msg.ack()


async def run_projector(subscription, store: OpenSearchStore, stop: asyncio.Event) -> None:
    while not stop.is_set():
        try:
            messages = await subscription.fetch(batch=50, timeout=2)
        except asyncio.TimeoutError:
            continue
        except Exception as exc:
            if type(exc).__name__ in {"TimeoutError", "NatsTimeoutError"}:
                continue
            await asyncio.sleep(1)
            continue
        for msg in messages:
            if stop.is_set():
                break
            await process_message(store, msg)
