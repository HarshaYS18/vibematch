"""Projection sinks for ClickHouse and Parquet/object storage."""

from __future__ import annotations

import asyncio
import hashlib
import io
from datetime import timezone
from pathlib import Path
from typing import Iterable

import boto3
import httpx
import pyarrow as pa
import pyarrow.parquet as pq

from config import Settings
from contracts import AnalyticsEvent


class AnalyticsSink:
    def __init__(self, settings: Settings, http: httpx.AsyncClient) -> None:
        self._settings = settings
        self._http = http
        self._s3 = None
        if settings.object_store_mode == "s3":
            self._s3 = boto3.client(
                "s3",
                endpoint_url=settings.object_store_endpoint or None,
                region_name=settings.object_store_region,
                aws_access_key_id=settings.object_store_access_key or None,
                aws_secret_access_key=settings.object_store_secret_key or None,
            )

    async def ensure_clickhouse(self) -> None:
        db = self._settings.clickhouse_database
        await self._query(f"CREATE DATABASE IF NOT EXISTS {db}")
        await self._query(
            f"""
            CREATE TABLE IF NOT EXISTS {db}.events_v1 (
              event_id UUID,
              event_type LowCardinality(String),
              event_version UInt16,
              schema_version UInt16,
              occurred_at DateTime64(3, 'UTC'),
              published_at DateTime64(3, 'UTC'),
              source_service LowCardinality(String),
              topic_family LowCardinality(String),
              partition_key String,
              actor_user_id Nullable(UInt64),
              traceparent Nullable(String),
              payload_json String
            )
            ENGINE = ReplacingMergeTree(published_at)
            PARTITION BY toYYYYMM(occurred_at)
            ORDER BY event_id
            """
        )

    async def write_batch(self, events: list[AnalyticsEvent]) -> None:
        if not events:
            return
        await self._write_clickhouse(events)
        parquet_bytes, key = self._parquet_batch(events)
        await self._write_lake(key, parquet_bytes)

    async def _write_clickhouse(self, events: list[AnalyticsEvent]) -> None:
        import json
        db = self._settings.clickhouse_database
        body = "\n".join(json.dumps(event.row(), separators=(",", ":")) for event in events)
        response = await self._http.post(
            f"{self._settings.clickhouse_url}/",
            params={"query": f"INSERT INTO {db}.events_v1 FORMAT JSONEachRow"},
            content=body.encode(),
            timeout=10.0,
        )
        response.raise_for_status()

    def _parquet_batch(self, events: list[AnalyticsEvent]) -> tuple[bytes, str]:
        rows = [event.row() for event in events]
        table = pa.Table.from_pylist(rows)
        buffer = io.BytesIO()
        pq.write_table(table, buffer, compression="zstd")

        event_ids = sorted(str(event.event_id) for event in events)
        digest = hashlib.sha256("\n".join(event_ids).encode()).hexdigest()[:24]
        first = min(event.occurred_at.astimezone(timezone.utc) for event in events)
        family = events[0].topic_family.replace("/", "_").replace(".", "_")
        key = (
            f"{self._settings.object_store_prefix}/"
            f"date={first:%Y-%m-%d}/family={family}/batch-{digest}.parquet"
        )
        return buffer.getvalue(), key

    async def _write_lake(self, key: str, payload: bytes) -> None:
        if self._settings.object_store_mode == "file":
            path = Path(self._settings.local_lake_path) / key
            await asyncio.to_thread(path.parent.mkdir, parents=True, exist_ok=True)
            await asyncio.to_thread(path.write_bytes, payload)
            return

        assert self._s3 is not None
        await asyncio.to_thread(
            self._s3.put_object,
            Bucket=self._settings.object_store_bucket,
            Key=key,
            Body=payload,
            ContentType="application/vnd.apache.parquet",
        )

    async def ready(self) -> bool:
        try:
            response = await self._http.get(
                f"{self._settings.clickhouse_url}/ping",
                timeout=2.0,
            )
            return response.status_code == 200
        except httpx.HTTPError:
            return False

    async def _query(self, sql: str) -> None:
        response = await self._http.post(
            f"{self._settings.clickhouse_url}/",
            params={"query": " ".join(sql.split())},
            timeout=10.0,
        )
        response.raise_for_status()
