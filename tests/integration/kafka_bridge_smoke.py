"""Controlled NATS -> Kafka bridge smoke/load check.

Requires disposable local NATS/Kafka/bridge. The event count is configurable so
staging can reuse the same harness for larger soak batches.
"""

from __future__ import annotations

import asyncio
import json
import os
import time
from datetime import datetime, timezone
from uuid import uuid4

import nats
from aiokafka import AIOKafkaConsumer


EVENT_COUNT = max(1, min(int(os.getenv("FUNKEY_KAFKA_SMOKE_EVENTS", "100")), 100000))


async def main() -> None:
    run_id = str(uuid4())
    expected: set[str] = set()
    consumer = AIOKafkaConsumer(
        "funkey.room.events.v1",
        bootstrap_servers="127.0.0.1:19092",
        group_id=f"funkey-bridge-smoke-{run_id}",
        enable_auto_commit=False,
        auto_offset_reset="earliest",
    )
    await consumer.start()
    # Force group assignment/offset initialization before publishing. Without
    # this, a fresh "latest" style consumer can race the first bridge writes.
    assignment_deadline = time.monotonic() + 15
    while not consumer.assignment() and time.monotonic() < assignment_deadline:
        await consumer.getmany(timeout_ms=250, max_records=1)
    if not consumer.assignment():
        raise RuntimeError("Kafka smoke consumer did not receive a partition assignment")
    for partition in consumer.assignment():
        await consumer.position(partition)

    nc = await nats.connect("nats://127.0.0.1:4222")
    js = nc.jetstream(timeout=3)
    started = time.monotonic()
    try:
        try:
            await js.stream_info("FUNKEY_EVENTS")
        except Exception:
            await js.add_stream(
                name="FUNKEY_EVENTS",
                subjects=["funkey.events.>"],
                max_age=7 * 86400,
            )

        for index in range(EVENT_COUNT):
            event_id = str(uuid4())
            expected.add(event_id)
            payload = {
                "event_id": event_id,
                "event_type": "room.joined",
                "event_version": 1,
                "occurred_at": datetime.now(timezone.utc).isoformat(),
                "request_id": f"kafka-smoke-{run_id}",
                "trace_id": f"kafka-smoke-{index}",
                "traceparent": None,
                "actor_user_id": 42,
                "payload": {
                    "room_public_id": f"ROOM-SMOKE-{index % 10}",
                    "smoke_run_id": run_id,
                    "sequence": index,
                },
            }
            await js.publish(
                "funkey.events.room.joined",
                json.dumps(payload).encode(),
                headers={"Nats-Msg-Id": event_id},
            )

        observed: set[str] = set()
        deadline = time.monotonic() + 30
        while expected - observed and time.monotonic() < deadline:
            remaining = max(0.1, deadline - time.monotonic())
            try:
                message = await asyncio.wait_for(
                    consumer.getone(),
                    timeout=min(2.0, remaining),
                )
            except TimeoutError:
                continue
            decoded = json.loads(message.value)
            if decoded.get("payload", {}).get("smoke_run_id") != run_id:
                continue
            assert decoded["topic_family"] == "room.events"
            assert message.key and message.key.startswith(b"ROOM-SMOKE-")
            observed.add(decoded["event_id"])

        missing = expected - observed
        assert not missing, f"silent loss detected: {len(missing)} of {EVENT_COUNT} events missing"
        elapsed = max(0.001, time.monotonic() - started)
        print(json.dumps({
            "status": "ok",
            "published": EVENT_COUNT,
            "observed_unique": len(observed),
            "silent_loss": 0,
            "elapsed_seconds": round(elapsed, 3),
            "events_per_second": round(EVENT_COUNT / elapsed, 2),
        }, sort_keys=True))
    finally:
        await consumer.stop()
        await nc.drain()


if __name__ == "__main__":
    asyncio.run(main())
