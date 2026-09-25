"""Environment-only configuration for the NATS -> Kafka analytics bridge."""

from __future__ import annotations

import os
import ssl
from dataclasses import dataclass


_ALLOWED_PROTOCOLS = {"PLAINTEXT", "SSL", "SASL_PLAINTEXT", "SASL_SSL"}
_ALLOWED_SASL = {"PLAIN", "SCRAM-SHA-256", "SCRAM-SHA-512"}


@dataclass(frozen=True)
class Settings:
    app_env: str
    nats_url: str
    nats_stream: str
    nats_dlq_stream: str
    nats_durable: str
    kafka_bootstrap_servers: str
    kafka_client_id: str
    kafka_security_protocol: str
    kafka_sasl_mechanism: str
    kafka_username: str
    kafka_password: str
    kafka_ca_file: str
    bridge_health_port: int
    bridge_batch_size: int
    bridge_max_in_flight: int
    bridge_nak_delay_seconds: float
    topic_replication_factor: int

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            app_env=os.getenv("APP_ENV", "development").strip().lower(),
            nats_url=os.getenv("NATS_URL", "nats://127.0.0.1:4222").strip(),
            nats_stream=os.getenv("NATS_STREAM", "FUNKEY_EVENTS").strip(),
            nats_dlq_stream=os.getenv("NATS_DLQ_STREAM", "FUNKEY_DLQ").strip(),
            nats_durable=os.getenv("KAFKA_BRIDGE_NATS_DURABLE", "funkey-kafka-bridge-v1").strip(),
            kafka_bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:19092").strip(),
            kafka_client_id=os.getenv("KAFKA_CLIENT_ID", "funkey-kafka-event-bridge").strip(),
            kafka_security_protocol=os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT").strip().upper(),
            kafka_sasl_mechanism=os.getenv("KAFKA_SASL_MECHANISM", "SCRAM-SHA-512").strip().upper(),
            kafka_username=os.getenv("KAFKA_USERNAME", "").strip(),
            kafka_password=os.getenv("KAFKA_PASSWORD", "").strip(),
            kafka_ca_file=os.getenv("KAFKA_CA_FILE", "").strip(),
            bridge_health_port=max(1, min(int(os.getenv("KAFKA_BRIDGE_HEALTH_PORT", "8092")), 65535)),
            bridge_batch_size=max(1, min(int(os.getenv("KAFKA_BRIDGE_BATCH_SIZE", "50")), 500)),
            bridge_max_in_flight=max(1, min(int(os.getenv("KAFKA_BRIDGE_MAX_IN_FLIGHT", "32")), 256)),
            bridge_nak_delay_seconds=max(0.5, min(float(os.getenv("KAFKA_BRIDGE_NAK_DELAY_SECONDS", "5")), 60.0)),
            topic_replication_factor=max(1, min(int(os.getenv("KAFKA_TOPIC_REPLICATION_FACTOR", "1")), 5)),
        )

    def validate(self) -> None:
        if not self.nats_url:
            raise RuntimeError("NATS_URL is required")
        if not self.kafka_bootstrap_servers:
            raise RuntimeError("KAFKA_BOOTSTRAP_SERVERS is required")
        if self.kafka_security_protocol not in _ALLOWED_PROTOCOLS:
            raise RuntimeError("unsupported KAFKA_SECURITY_PROTOCOL")
        if self.app_env == "production" and self.kafka_security_protocol != "SASL_SSL":
            raise RuntimeError("production Kafka requires KAFKA_SECURITY_PROTOCOL=SASL_SSL")
        if self.kafka_sasl_mechanism not in _ALLOWED_SASL:
            raise RuntimeError("unsupported KAFKA_SASL_MECHANISM")
        if self.kafka_security_protocol.startswith("SASL_"):
            if not self.kafka_username or not self.kafka_password:
                raise RuntimeError("Kafka SASL username/password are required")
        if self.kafka_security_protocol.endswith("_SSL") or self.kafka_security_protocol == "SSL":
            if self.kafka_ca_file and not os.path.isfile(self.kafka_ca_file):
                raise RuntimeError("KAFKA_CA_FILE does not exist")

    def kafka_client_kwargs(self) -> dict[str, object]:
        self.validate()
        kwargs: dict[str, object] = {
            "bootstrap_servers": [value.strip() for value in self.kafka_bootstrap_servers.split(",") if value.strip()],
            "client_id": self.kafka_client_id,
            "security_protocol": self.kafka_security_protocol,
        }
        if self.kafka_security_protocol.startswith("SASL_"):
            kwargs.update(
                sasl_mechanism=self.kafka_sasl_mechanism,
                sasl_plain_username=self.kafka_username,
                sasl_plain_password=self.kafka_password,
            )
        if self.kafka_security_protocol.endswith("_SSL") or self.kafka_security_protocol == "SSL":
            kwargs["ssl_context"] = ssl.create_default_context(cafile=self.kafka_ca_file or None)
        return kwargs
