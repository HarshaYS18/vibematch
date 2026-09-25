# Chunk 37 — Kafka Data Platform

**Status: implementation complete; CI and controlled integration/chaos evidence are the closure gates.**

Chunk 37 keeps NATS JetStream as FunKey's operational async bus and adds Kafka
only for retained analytics, replay, ML/recommendation and data-lake workloads.

## M1 — authority contract and event taxonomy

- ADR-017 establishes the NATS/Kafka split.
- PostgreSQL remains durable business authority.
- The only approved application path into Kafka is transactional outbox -> NATS JetStream -> Kafka Event Bridge.
- Direct Kafka clients are forbidden in domain services by `check_kafka_data_platform.py`.
- Seven analytics families plus one DLQ topic are canonicalized in `contracts/events/kafka-topics-v1.json`.

## M2 — versioned retained envelope

- `kafka-analytics-envelope-v1.schema.json` preserves event identity and occurrence time.
- The bridge adds publication time, source domain, topic family and deterministic partition key.
- Unknown top-level fields are rejected.
- Secret-looking payload keys are blocked before Kafka publication.
- Consumers use `event_id` as their durable idempotency key.

## M3 — KRaft infrastructure

- Local Docker Compose uses an opt-in single-node KRaft broker.
- Staging manifests provide a three-node KRaft quorum with replication factor 3 and min ISR 2.
- Production intentionally does not deploy the staging Kafka StatefulSets; it uses a managed multi-AZ Kafka endpoint with SASL_SSL.
- Auto topic creation is disabled.

## M4 — NATS -> Kafka bridge

- Dedicated `apps/kafka-event-bridge` runtime.
- Shared durable pull consumer `funkey-kafka-bridge-v1`.
- Source ACK happens only after Kafka ACK.
- Kafka producer idempotence and `acks=all` are enabled.
- Kafka outages NAK the NATS source; user commands never wait on Kafka.
- Poison/sensitive events go to the durable NATS DLQ before source ACK.

## M5 — topic/partition/retention policy

Canonical topics:

- `funkey.user.activity.v1`
- `funkey.room.events.v1`
- `funkey.vibes.engagement.v1`
- `funkey.economy.analytics.v1`
- `funkey.game.events.v1`
- `funkey.media.events.v1`
- `funkey.recommendation.events.v1`
- `funkey.analytics.dlq.v1`

Ordering is entity-scoped using stable user/room/game/media/economy keys. The
catalogue defines partitions and retention and is provisioned explicitly.

## M6 — consumer framework

- Manual Kafka offset commit only after projection success.
- Auto-commit is disabled.
- Projection sinks must be idempotent on `event_id`.
- Invalid retained events are quarantined with source topic/partition/offset provenance.
- Analytics projections remain disposable derivatives, not command authority.

## M7 — replay/backfill

- `replay.py` is dry-run by default.
- Replay windows require timezone-aware timestamps and are capped at 31 days.
- Source and destination topics must differ.
- Executed replay adds replay ID and original topic/partition/offset headers.
- Replay cannot directly invoke transactional command paths.

## M8 — analytics/recommendation boundary

The consumer framework is the approved downstream boundary for analytics,
recommendation, search and lake integrations. No projection is allowed to
authorize wallet, room, moderation, identity or settlement mutations.

## M9 — observability

The bridge exposes readiness plus low-cardinality metrics for received,
published, filtered, failed, quarantined and in-flight events and Kafka publish
latency. The operational runbook requires JetStream durable lag/age, Kafka
consumer lag, broker ISR/storage health, DLQ and replay telemetry.

## M10 — security

- Production Kafka defaults to SASL_SSL.
- Credentials come from Kubernetes secret storage and are never committed.
- Kafka ACLs are least privilege by producer/topic and consumer group.
- Secret/token/password/OTP/card-secret payload keys are rejected.
- Production managed Kafka is private-network/TLS infrastructure.

## M11 — load/failure/recovery tests

- Unit tests cover routing, partition keys, ACK ordering, retry behavior, poison quarantine, topic catalogue, DLQ provenance and replay bounds.
- Controlled integration test publishes a configurable batch (100 events by default) into JetStream and verifies every event ID reaches Kafka with zero silent loss.
- Kafka broker recovery chaos harness is staging-only and refuses production namespaces.
- Duplicate/redelivery is expected; downstream idempotency is mandatory.

## M12 — CI, rollback and documentation

- Production Platform CI compiles/tests/builds the bridge, runs the architecture guard, starts disposable NATS/Kafka, provisions topics and executes the end-to-end bridge smoke.
- Bridge image is published and production-pinned like other backend workloads.
- Architecture, module, contracts, runbook, external prerequisites and this chunk document are mandatory.
- Rollback disables/rolls back only the analytics bridge; operational NATS and business commands remain unaffected.

## Definition of done

Chunk 37 closes only when all repository CI is green and the controlled path
proves:

```text
PostgreSQL/outbox -> NATS -> bridge -> Kafka -> test consumer
```

with the same event ID, no silent loss in the controlled sample, architecture
guards green, image/manifests renderable, and rollback/replay procedures
documented.

A production Kafka provider/account/credentials remain an external deployment
prerequisite; repository completion is not a claim that a live provider has
already been provisioned.
