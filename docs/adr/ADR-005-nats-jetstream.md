# ADR-005: NATS JetStream as the operational distributed event broker

Status: Accepted and implemented

## Context

Background work and cross-replica operational delivery need durable at-least-once transport. Redis Pub/Sub alone does not retain missed work.

## Decision

NATS JetStream is FunKey's primary **operational** durable broker. Use a versioned envelope with event_id, event_type, event_version, occurred_at, request_id, trace_id, actor_user_id and payload. Keep synchronous calls for decisions needing immediate authority.

Chunk 37 adds Kafka behind the NATS bridge for a different purpose: long retention, replay, analytics, ML/recommendation and data-lake streams. Kafka does not replace NATS and must not be used for normal RPC.

## Consequences

Handlers must be idempotent, use bounded backoff/jitter, and route poison messages to a dead-letter/operator-review path. A transactional outbox is required when a DB commit and publication must be atomic from the user's perspective.

The canonical analytical copy path is:

```text
PostgreSQL transaction -> outbox -> NATS JetStream -> Kafka Event Bridge -> Kafka
```

Domain services must not dual-write Kafka.

## Validation and change criteria

Do not claim a domain event is published until its producer, contract, integration test and replay semantics exist. Monitor consumer lag and oldest message age. See ADR-017 for the Kafka boundary.
