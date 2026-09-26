# ADR-017: Kafka for long-retained analytics and replay

Status: Accepted and implemented in Chunk 37

## Context

NATS JetStream already provides durable at-least-once operational messaging. FunKey also needs longer retention, deterministic replay/backfill, analytics/ML pipelines, recommendation features and data-lake integrations. Using one broker for both operational low-latency work and long-retained analytical history would couple unrelated failure and retention requirements.

## Decision

Keep NATS JetStream as the operational async bus. Add Kafka as a separate analytics/replay data platform behind one NATS -> Kafka bridge.

Canonical path:

```text
PostgreSQL transaction
  -> transactional outbox
  -> NATS JetStream
  -> Kafka Event Bridge
  -> Kafka
  -> analytics / ML / recommendation / lake consumers
```

Kafka is forbidden for ordinary synchronous RPC and may not become application business authority.

## Delivery semantics

The bridge is at-least-once from NATS to Kafka. It acknowledges the source only after Kafka acknowledges the record. Kafka producer idempotence is enabled, but consumers still treat `event_id` as the durable idempotency key because retries and replay may create duplicate observations.

## Partitioning

Ordering is entity-scoped, never global. Room events use room identity when available; user activity uses user identity; gameplay uses session/round identity; all families have deterministic fallbacks.

## Production topology

Local development uses one KRaft broker. Staging has an in-cluster three-node KRaft integration cluster. Production uses a managed multi-AZ Kafka service with TLS/SASL, broker storage/partition monitoring and least-privilege ACLs. Production does not run the staging StatefulSets.

## Consequences

- Kafka failure cannot fail a normal user command.
- Bridge lag is observable and recoverable.
- Replay is bounded, dry-run-first and cannot target its source topic.
- Poison analytics events are quarantined.
- Domain services are prohibited from importing Kafka clients directly.
