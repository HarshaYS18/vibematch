"""Configuration for the FunKey Recommendation projection service."""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    kafka_bootstrap_servers: str
    kafka_security_protocol: str
    kafka_username: str
    kafka_password: str
    redis_url: str
    port: int
    feed_ttl_seconds: int
    group_id: str

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            kafka_bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:19092").strip(),
            kafka_security_protocol=os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT").strip().upper(),
            kafka_username=os.getenv("KAFKA_USERNAME", "").strip(),
            kafka_password=os.getenv("KAFKA_PASSWORD", "").strip(),
            redis_url=os.getenv("RECOMMENDATION_REDIS_URL", os.getenv("CACHE_REDIS_URL", "redis://127.0.0.1:6379/0")).strip(),
            port=max(1, min(int(os.getenv("RECOMMENDATION_PORT", "8094")), 65535)),
            feed_ttl_seconds=max(60, min(int(os.getenv("RECOMMENDATION_FEED_TTL_SECONDS", "21600")), 86400)),
            group_id=os.getenv("RECOMMENDATION_KAFKA_GROUP", "funkey-recommendation-v1").strip(),
        )

    def kafka_kwargs(self) -> dict[str, object]:
        kwargs: dict[str, object] = {
            "bootstrap_servers": [x.strip() for x in self.kafka_bootstrap_servers.split(",") if x.strip()],
            "security_protocol": self.kafka_security_protocol,
        }
        if self.kafka_security_protocol.startswith("SASL_"):
            if not self.kafka_username or not self.kafka_password:
                raise RuntimeError("Kafka SASL credentials required")
            kwargs.update(
                sasl_mechanism="SCRAM-SHA-512",
                sasl_plain_username=self.kafka_username,
                sasl_plain_password=self.kafka_password,
            )
        return kwargs


settings = Settings.from_env()
