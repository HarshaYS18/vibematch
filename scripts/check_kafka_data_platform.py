"""Chunk 37 Kafka data-platform architecture guard.

The guard is intentionally stdlib-only so infrastructure CI can enforce the
boundary before installing application dependencies.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "apps" / "kafka-event-bridge"

EXPECTED_TOPICS = {
    "funkey.user.activity.v1",
    "funkey.room.events.v1",
    "funkey.vibes.engagement.v1",
    "funkey.economy.analytics.v1",
    "funkey.game.events.v1",
    "funkey.media.events.v1",
    "funkey.recommendation.events.v1",
    "funkey.analytics.dlq.v1",
}


def require(path: Path, markers: tuple[str, ...]) -> str:
    if not path.is_file():
        raise SystemExit(f"missing required Kafka platform file: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            raise SystemExit(
                f"{path.relative_to(ROOT)} is missing required marker: {marker}"
            )
    return text


def check_contracts() -> None:
    catalogue = json.loads(
        (ROOT / "contracts/events/kafka-topics-v1.json").read_text(encoding="utf-8")
    )
    names = {item["name"] for item in catalogue["topics"]}
    if names != EXPECTED_TOPICS:
        raise SystemExit(f"Kafka topic contract drift: {sorted(names ^ EXPECTED_TOPICS)}")
    for item in catalogue["topics"]:
        if item.get("data_classification") not in {"internal_analytics", "restricted_analytics"}:
            raise SystemExit(f"Kafka topic lacks valid data classification: {item.get('name')}")

    schema = json.loads(
        (ROOT / "contracts/events/kafka-analytics-envelope-v1.schema.json").read_text(
            encoding="utf-8"
        )
    )
    if schema.get("additionalProperties") is not False:
        raise SystemExit("Kafka analytics envelope must reject unknown top-level fields")
    required = set(schema.get("required", []))
    for field in {
        "event_id", "event_type", "event_version", "schema_version",
        "occurred_at", "published_at", "source_service", "topic_family",
        "partition_key", "payload",
    }:
        if field not in required:
            raise SystemExit(f"Kafka envelope missing required field: {field}")

    acl = json.loads(
        (ROOT / "contracts/events/kafka-acl-policy-v1.json").read_text(encoding="utf-8")
    )
    if acl.get("schema_version") != 1 or not acl.get("principals"):
        raise SystemExit("Kafka ACL policy v1 is missing or malformed")
    acl_text = json.dumps(acl, sort_keys=True)
    for marker in ("bridge_producer", "projection_consumer", "replay_operator", "funkey.replay.*"):
        if marker not in acl_text:
            raise SystemExit(f"Kafka ACL policy missing marker: {marker}")


def check_bridge() -> None:
    bridge = require(
        BRIDGE / "bridge.py",
        (
            "await publish_to_kafka(producer, envelope)",
            "await msg.ack()",
            "await msg.nak",
            "funkey.dlq.kafka_bridge.invalid",
        ),
    )
    publish_at = bridge.index("await publish_to_kafka(producer, envelope)")
    try:
        ack_after_publish = bridge.index("await msg.ack()", publish_at)
    except ValueError as exc:
        raise SystemExit("Kafka bridge must ACK JetStream after Kafka publication") from exc
    if ack_after_publish <= publish_at:
        raise SystemExit("Kafka bridge must ACK JetStream only after Kafka publication")

    require(
        BRIDGE / "main.py",
        (
            "enable_idempotence=True",
            'acks="all"',
            "funkey.events.>",
            "durable=settings.nats_durable",
            "monitor_source_lag",
        ),
    )
    require(
        BRIDGE / "contracts.py",
        (
            "FORBIDDEN_PAYLOAD_KEYS",
            "partition_key_for",
            "topic_family_for",
            "sensitive_payload_paths",
        ),
    )
    require(
        BRIDGE / "consumer.py",
        ("enable_auto_commit=False", "await consumer.commit()", "funkey.analytics.dlq.v1"),
    )
    require(
        BRIDGE / "replay.py",
        (
            "replay destination must differ from source topic",
            "funkey.replay.*",
            "31 * 86400",
            "--execute",
            "funkey-replay-id",
        ),
    )


def check_no_domain_kafka_clients() -> None:
    pattern = re.compile(
        r"(^|\n)\s*(from\s+(aiokafka|kafka|confluent_kafka)|import\s+(aiokafka|kafka|confluent_kafka))"
    )
    roots = [ROOT / "backend", ROOT / "apps"]
    offenders: list[str] = []
    for base in roots:
        for path in base.rglob("*.py"):
            if BRIDGE in path.parents:
                continue
            if pattern.search(path.read_text(encoding="utf-8", errors="replace")):
                offenders.append(str(path.relative_to(ROOT)))
    if offenders:
        raise SystemExit(
            "Kafka clients are forbidden outside kafka-event-bridge: "
            + ", ".join(sorted(offenders))
        )


def check_infrastructure() -> None:
    compose = require(
        ROOT / "infra/docker-compose.yml",
        (
            "apache/kafka:4.1.0",
            "KAFKA_PROCESS_ROLES",
            "kafka-event-bridge",
            "kafka-topics",
            "KAFKA_AUTO_CREATE_TOPICS_ENABLE",
        ),
    )
    if 'profiles: ["data"]' not in compose:
        raise SystemExit("local Kafka must remain opt-in behind the data profile")

    require(
        ROOT / "deploy/kubernetes/base/kafka-event-bridge.yaml",
        (
            "funkey-kafka-event-bridge",
            "readOnlyRootFilesystem: true",
            "funkey-kafka-secrets",
        ),
    )
    base = require(
        ROOT / "deploy/kubernetes/base/kustomization.yaml",
        ("kafka-event-bridge.yaml",),
    )
    staging = require(
        ROOT / "deploy/kubernetes/overlays/staging/kustomization.yaml",
        ("../../kafka",),
    )
    production = (ROOT / "deploy/kubernetes/overlays/production/kustomization.yaml").read_text(
        encoding="utf-8"
    )
    if "../../kafka" in production:
        raise SystemExit("production must use managed Kafka, not staging KRaft manifests")
    if "funkey-kafka-event-bridge" not in production:
        raise SystemExit("production overlay must pin Kafka bridge image by digest")

    require(
        ROOT / "deploy/kafka/kafka.yaml",
        (
            "KAFKA_PROCESS_ROLES",
            "KAFKA_CONTROLLER_QUORUM_VOTERS",
            "KAFKA_MIN_INSYNC_REPLICAS",
            "minAvailable: 2",
        ),
    )


def check_worker_boundary() -> None:
    pools = require(
        ROOT / "apps/worker/pools.py",
        ('"analytics": PoolSpec("analytics", (), frozenset(), max_in_flight=8, active=False)',),
    )
    if "active=False" not in pools:
        raise SystemExit("legacy analytics worker boundary must remain inactive")


def check_docs_and_ci() -> None:
    for path in (
        ROOT / "docs/adr/ADR-017-kafka-data-platform.md",
        ROOT / "docs/architecture/kafka-data-platform.md",
        ROOT / "docs/modules/kafka-event-bridge/README.md",
        ROOT / "docs/runbooks/kafka-data-platform.md",
        ROOT / "docs/platform/chunk37-kafka-data-platform.md",
        ROOT / "deploy/kafka/README.md",
        BRIDGE / "README.md",
        BRIDGE / "tests/README.md",
    ):
        require(path, ("Kafka",))

    workflow = require(
        ROOT / ".github/workflows/production-platform.yml",
        (
            "check_kafka_data_platform.py",
            "Kafka data platform",
            "apps/kafka-event-bridge/requirements.txt",
            "kafka_bridge_smoke.py",
        ),
    )
    publish = require(
        ROOT / ".github/workflows/publish-backend-images.yml",
        ("kafka-event-bridge",),
    )
    if "kafka-event-bridge" not in workflow or "kafka-event-bridge" not in publish:
        raise SystemExit("Kafka bridge must be built and published by CI")

    require(
        ROOT / "deploy/observability/prometheus-rules.yaml",
        (
            "FunKeyKafkaBridgeDown",
            "FunKeyKafkaBridgePublishFailures",
            "FunKeyKafkaBridgeSourceBacklog",
        ),
    )
    require(
        ROOT / "deploy/observability/grafana-dashboard.yaml",
        ("Kafka bridge throughput", "Kafka bridge source backlog"),
    )
    require(
        ROOT / "scripts/prepare_gitops_promotion.py",
        ("kafka_event_bridge", "graphql_bff"),
    )


def main() -> None:
    check_contracts()
    check_bridge()
    check_no_domain_kafka_clients()
    check_infrastructure()
    check_worker_boundary()
    check_docs_and_ci()
    print("Kafka data platform architecture guard: OK")


if __name__ == "__main__":
    main()
