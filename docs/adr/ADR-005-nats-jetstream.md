# ADR-005: NATS JetStream as primary distributed event broker

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

Background work and cross-replica delivery need durable at-least-once transport. Redis Pub/Sub alone does not retain missed work.

## Decision

Select NATS JetStream as the single primary durable broker. Use a versioned envelope with event_id, event_type, event_version, occurred_at, request_id, trace_id, actor_user_id, and payload. Keep synchronous calls for decisions needing immediate authority.

## Consequences

Handlers must be idempotent, use bounded backoff/jitter, and route poison messages to a dead-letter or operator review path. An outbox is required when a DB commit and publication must be atomic from the user's perspective.

## Validation and change criteria

Do not claim a domain event is published until its producer, contract, integration test, and replay semantics exist. Monitor consumer lag and oldest message age.
