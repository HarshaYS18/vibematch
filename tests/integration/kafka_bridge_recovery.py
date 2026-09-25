"""Controlled Kafka outage/recovery check for the NATS -> Kafka bridge."""

from __future__ import annotations

import argparse
import asyncio
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

import nats
from aiokafka import AIOKafkaConsumer


EVENT_COUNT = 20


async def publish_state(path: Path) -> None:
    run_id = str(uuid4())
    ids: list[str] = []
    nc = await nats.connect("nats://127.0.0.1:4222")
    js = nc.jetstream(timeout=3)
    try:
        for index in range(EVENT_COUNT):
            event_id = str(uuid4())
            ids.append(event_id)
            payload = {
                "event_id": event_id,
                "event_type": "room.joined",
                "event_version": 1,
                "occurred_at": datetime.now(timezone.utc).isoformat(),
                "request_id": f"kafka-recovery-{run_id}",
                "trace_id": f"kafka-recovery-{index}",
                "traceparent": None,
                "actor_user_id": 42,
                "payload": {
                    "room_public_id": f"ROOM-RECOVERY-{index % 4}",
                    "recovery_run_id": run_id,
                    "sequence": index,
                },
            }
            await js.publish(
                "funkey.events.room.joined",
                json.dumps(payload).encode(),
                headers={"Nats-Msg-Id": event_id},
            )
        path.write_text(
            json.dumps({"run_id": run_id, "event_ids": ids}, sort_keys=True),
            encoding="utf-8",
        )
        print(json.dumps({"phase": "publish", "events": EVENT_COUNT, "run_id": run_id}))
    finally:
        await nc.drain()


async def verify_state(path: Path) -> None:
    state = json.loads(path.read_text(encoding="utf-8"))
    expected = set(state["event_ids"])
    run_id = state["run_id"]
    consumer = AIOKafkaConsumer(
        "funkey.room.events.v1",
        bootstrap_servers="127.0.0.1:19092",
        group_id=f"funkey-bridge-recovery-{run_id}",
        enable_auto_commit=False,
        auto_offset_reset="earliest",
    )
    await consumer.start()
    observed: set[str] = set()
    started = time.monotonic()
    try:
        assignment_deadline = time.monotonic() + 15
        while not consumer.assignment() and time.monotonic() < assignment_deadline:
            await consumer.getmany(timeout_ms=250, max_records=1)
        if not consumer.assignment():
            raise RuntimeError("Kafka recovery consumer did not receive a partition assignment")

        deadline = time.monotonic() + 45
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
            if decoded.get("payload", {}).get("recovery_run_id") != run_id:
                continue
            observed.add(decoded["event_id"])

        missing = expected - observed
        if missing:
            raise AssertionError(
                f"recovery silent loss: {len(missing)} of {len(expected)} events missing"
            )
        elapsed = max(0.001, time.monotonic() - started)
        print(json.dumps({
            "phase": "verify",
            "published_during_outage": len(expected),
            "observed_unique": len(observed),
            "silent_loss": 0,
            "elapsed_seconds": round(elapsed, 3),
            "status": "ok",
        }, sort_keys=True))
    finally:
        await consumer.stop()


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument("phase", choices=("publish", "verify"))
    p.add_argument("--state-file", required=True)
    return p


async def main() -> None:
    args = parser().parse_args()
    path = Path(args.state_file)
    if args.phase == "publish":
        await publish_state(path)
    else:
        await verify_state(path)


if __name__ == "__main__":
    asyncio.run(main())
