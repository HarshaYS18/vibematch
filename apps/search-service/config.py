"""Environment configuration for the FunKey Search/OpenSearch projection service."""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    opensearch_url: str
    index_prefix: str
    nats_url: str
    nats_stream: str
    durable: str
    port: int

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            opensearch_url=os.getenv("OPENSEARCH_URL", "http://127.0.0.1:9200").rstrip("/"),
            index_prefix=os.getenv("SEARCH_INDEX_PREFIX", "funkey-search-v1").strip(),
            nats_url=os.getenv("NATS_URL", "nats://127.0.0.1:4222").strip(),
            nats_stream=os.getenv("NATS_STREAM", "FUNKEY_EVENTS").strip(),
            durable=os.getenv("SEARCH_NATS_DURABLE", "funkey-search-projector-v1").strip(),
            port=max(1, min(int(os.getenv("SEARCH_PORT", "8093")), 65535)),
        )


settings = Settings.from_env()
