"""Configuration for the Kafka -> ClickHouse/Parquet analytics sink."""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    app_env: str
    kafka_bootstrap_servers: str
    kafka_security_protocol: str
    kafka_username: str
    kafka_password: str
    kafka_group: str
    clickhouse_url: str
    clickhouse_database: str
    object_store_mode: str
    object_store_bucket: str
    object_store_prefix: str
    object_store_endpoint: str
    object_store_region: str
    object_store_access_key: str
    object_store_secret_key: str
    local_lake_path: str
    port: int

    @classmethod
    def from_env(cls) -> "Settings":
        value = cls(
            app_env=os.getenv("APP_ENV", "development").strip().lower(),
            kafka_bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:19092").strip(),
            kafka_security_protocol=os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT").strip().upper(),
            kafka_username=os.getenv("KAFKA_USERNAME", "").strip(),
            kafka_password=os.getenv("KAFKA_PASSWORD", "").strip(),
            kafka_group=os.getenv("ANALYTICS_KAFKA_GROUP", "funkey-analytics-sink-v1").strip(),
            clickhouse_url=os.getenv("CLICKHOUSE_URL", "http://127.0.0.1:18123").rstrip("/"),
            clickhouse_database=os.getenv("CLICKHOUSE_DATABASE", "funkey_analytics").strip(),
            object_store_mode=os.getenv("ANALYTICS_OBJECT_STORE_MODE", "file").strip().lower(),
            object_store_bucket=os.getenv("ANALYTICS_OBJECT_STORE_BUCKET", "").strip(),
            object_store_prefix=os.getenv("ANALYTICS_OBJECT_STORE_PREFIX", "funkey/events/v1").strip("/"),
            object_store_endpoint=os.getenv("ANALYTICS_OBJECT_STORE_ENDPOINT", "").strip(),
            object_store_region=os.getenv("ANALYTICS_OBJECT_STORE_REGION", "ap-south-1").strip(),
            object_store_access_key=os.getenv("ANALYTICS_OBJECT_STORE_ACCESS_KEY", "").strip(),
            object_store_secret_key=os.getenv("ANALYTICS_OBJECT_STORE_SECRET_KEY", "").strip(),
            local_lake_path=os.getenv("ANALYTICS_LOCAL_LAKE_PATH", "/tmp/funkey-lake").strip(),
            port=max(1, min(int(os.getenv("ANALYTICS_PORT", "8095")), 65535)),
        )
        value.validate()
        return value

    def validate(self) -> None:
        if self.object_store_mode not in {"file", "s3"}:
            raise RuntimeError("ANALYTICS_OBJECT_STORE_MODE must be file or s3")
        if self.app_env in {"production", "prod"}:
            if self.kafka_security_protocol != "SASL_SSL":
                raise RuntimeError("production analytics requires KAFKA_SECURITY_PROTOCOL=SASL_SSL")
            if not self.kafka_username or not self.kafka_password:
                raise RuntimeError("production analytics requires Kafka credentials")
            if self.object_store_mode != "s3" or not self.object_store_bucket:
                raise RuntimeError("production analytics requires S3-compatible object storage")

    def kafka_kwargs(self) -> dict[str, object]:
        kwargs: dict[str, object] = {
            "bootstrap_servers": [x.strip() for x in self.kafka_bootstrap_servers.split(",") if x.strip()],
            "security_protocol": self.kafka_security_protocol,
        }
        if self.kafka_security_protocol.startswith("SASL_"):
            kwargs.update(
                sasl_mechanism="SCRAM-SHA-512",
                sasl_plain_username=self.kafka_username,
                sasl_plain_password=self.kafka_password,
            )
        return kwargs


settings = Settings.from_env()
