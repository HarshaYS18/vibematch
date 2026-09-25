# FunKey Kafka Event Bridge

Chunk 37 adds Kafka as a **long-retained analytics/replay platform** without replacing NATS JetStream.

## Data path

```text
PostgreSQL transaction
  -> transactional outbox
  -> NATS JetStream
  -> kafka-event-bridge
  -> Kafka
  -> analytics / ML / recommendation / lake consumers
```

The bridge is the only application component allowed to mirror operational NATS events into Kafka. Domain services must not dual-write Kafka.

## Files

- `main.py`: runtime, health, readiness, graceful drain
- `bridge.py`: bounded JetStream pull/ack and Kafka publication
- `contracts.py`: versioned analytics envelope, routing and PII/secret-key guard
- `topics.py`: canonical topic catalogue and provisioning
- `consumer.py`: manual-commit projection-consumer framework
- `replay.py`: bounded dry-run-first replay/backfill CLI
- `metrics.py`: low-cardinality bridge metrics
- `config.py`: TLS/SASL/plaintext environment configuration
- `provision_topics.py`: topic provisioning entrypoint
- `tests/`: unit and architecture-contract tests

## Delivery semantics

Source delivery is at-least-once. A JetStream message is acknowledged only after Kafka acknowledges the record. Kafka producer idempotence is enabled, but downstream consumers must still use `event_id` as their durable idempotency key because retries, replay and consumer crashes can create duplicate observations.

Unclassified operational events are acknowledged by this bridge and intentionally not copied. Invalid/sensitive events are durably quarantined to the existing NATS DLQ stream before the source message is acknowledged.

## Observability

`/metrics` exposes bridge outcomes, Kafka publish latency, in-flight work and JetStream durable `source_pending`, `source_ack_pending` and `source_redelivered` gauges. Labels remain bounded to result/topic-family dimensions.

## Authority

Kafka is never wallet, room, identity, profile, moderation, inbox or game-settlement authority. A Kafka outage must not fail a normal user command. The operational outbox/NATS path remains independent.

## Security

Production uses `SASL_SSL` by default. Credentials are injected from secret storage and must never be committed. Payload keys that look like credentials, OTPs, bearer tokens or card secrets are rejected before Kafka publication. Topic access should use least-privilege ACLs for the bridge producer and each consumer group.

## Replay

`replay.py` is dry-run by default and requires a bounded timezone-aware interval. It refuses source=destination. Execution adds replay provenance in Kafka headers and does not invoke synchronous business commands.

See `docs/runbooks/kafka-data-platform.md` before any replay.
