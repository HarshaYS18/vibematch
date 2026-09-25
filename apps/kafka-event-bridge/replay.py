"""Bounded, auditable Kafka replay tool. Dry-run is the default."""

from __future__ import annotations

import argparse
import asyncio
import json
from datetime import datetime, timezone
from uuid import uuid4

from aiokafka import AIOKafkaConsumer, AIOKafkaProducer, TopicPartition

from config import Settings


def parse_utc(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("replay timestamps must include a timezone")
    return parsed.astimezone(timezone.utc)


def validate_destination(source_topic: str, destination_topic: str) -> None:
    if source_topic == destination_topic:
        raise ValueError("replay destination must differ from source topic")
    if not destination_topic.startswith("funkey.replay."):
        raise ValueError("replay destination must use the isolated funkey.replay.* namespace")


def validate_window(start: datetime, end: datetime) -> None:
    if end <= start:
        raise ValueError("replay end must be after start")
    if (end - start).total_seconds() > 31 * 86400:
        raise ValueError("one replay invocation is limited to 31 days")


async def replay(
    settings: Settings,
    *,
    source_topic: str,
    destination_topic: str,
    start: datetime,
    end: datetime,
    execute: bool,
) -> dict[str, int | str | bool]:
    validate_destination(source_topic, destination_topic)
    validate_window(start, end)
    replay_id = str(uuid4())

    common = settings.kafka_client_kwargs()
    consumer = AIOKafkaConsumer(**common, enable_auto_commit=False)
    producer = AIOKafkaProducer(**common, acks="all", enable_idempotence=True)
    await consumer.start()
    if execute:
        await producer.start()

    scanned = 0
    emitted = 0
    try:
        partitions = await consumer.partitions_for_topic(source_topic)
        if not partitions:
            raise RuntimeError("source topic does not exist or has no partitions")

        tps = [TopicPartition(source_topic, partition) for partition in sorted(partitions)]
        offsets = await consumer.offsets_for_times({
            tp: int(start.timestamp() * 1000)
            for tp in tps
        })
        consumer.assign(tps)
        for tp in tps:
            offset_time = offsets.get(tp)
            if offset_time is not None:
                consumer.seek(tp, offset_time.offset)
            else:
                end_offset = (await consumer.end_offsets([tp]))[tp]
                consumer.seek(tp, end_offset)

        done: set[TopicPartition] = set()
        while len(done) < len(tps):
            batch = await consumer.getmany(timeout_ms=1000, max_records=500)
            if not batch:
                break
            for tp, messages in batch.items():
                for message in messages:
                    occurred = datetime.fromtimestamp(message.timestamp / 1000, tz=timezone.utc)
                    if occurred >= end:
                        done.add(tp)
                        break
                    scanned += 1
                    if execute:
                        headers = list(message.headers or [])
                        headers.extend([
                            ("funkey-replay-id", replay_id.encode()),
                            ("funkey-original-topic", source_topic.encode()),
                            ("funkey-original-partition", str(message.partition).encode()),
                            ("funkey-original-offset", str(message.offset).encode()),
                        ])
                        await producer.send_and_wait(
                            destination_topic,
                            message.value,
                            key=message.key,
                            headers=headers,
                        )
                        emitted += 1
        return {
            "replay_id": replay_id,
            "source_topic": source_topic,
            "destination_topic": destination_topic,
            "execute": execute,
            "scanned": scanned,
            "emitted": emitted,
        }
    finally:
        await consumer.stop()
        if execute:
            await producer.stop()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-topic", required=True)
    parser.add_argument("--destination-topic", required=True)
    parser.add_argument("--start", required=True, help="ISO-8601 inclusive start")
    parser.add_argument("--end", required=True, help="ISO-8601 exclusive end")
    parser.add_argument("--execute", action="store_true", help="publish instead of dry-run")
    return parser


async def _run(args: argparse.Namespace) -> None:
    settings = Settings.from_env()
    settings.validate()
    result = await replay(
        settings,
        source_topic=args.source_topic,
        destination_topic=args.destination_topic,
        start=parse_utc(args.start),
        end=parse_utc(args.end),
        execute=bool(args.execute),
    )
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    asyncio.run(_run(_parser().parse_args()))
