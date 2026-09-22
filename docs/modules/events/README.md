# Events

## Purpose

Defines versioned domain event envelopes and asynchronous delivery boundaries.

## Responsibilities

Event contracts and broker delivery; not synchronous business authorization.

## What this module owns

Event contracts and broker delivery; not synchronous business authorization.

## What this module does NOT own

This module does not take over an adjacent domain merely because it transports or caches its data.

## Source of truth

PostgreSQL remains the durable source of truth for application state.

## Important files

`backend/app/realtime/events.py`, `backend/app/realtime/event_bus.py`, `backend/app/services/event_outbox_service.py`, `backend/app/services/outbox_relay_service.py`, `apps/worker/events.py`, and `contracts/events/`.

## Public API/contracts

Existing room event names; NATS JetStream envelope is the selected target. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published

NATS JetStream is the selected broker. Contracts must carry event_id, event_type, event_version, occurred_at, request_id, trace_id, actor_user_id, and payload. The broker is at-least-once; consumers deduplicate.

## Events consumed

Implemented durable contracts use the worker's JetStream pull consumer with explicit ack, bounded retry, idempotent handlers and dead-letter publication. Realtime Redis Pub/Sub remains intentionally ephemeral and separate.

## Database tables/state owned

Database: No direct tables unless transactional outbox/inbox records are added.

## Redis keys/state owned

Transport coordination and dedupe leases may be transient.

## Dependencies

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable.

## Security considerations

Never place secrets or unnecessary PII in payloads; authorize consumers. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes

At-least-once delivery requires idempotent handlers, bounded retries, and dead-letter inspection.

## Retry/idempotency behavior

Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling behavior

Scale this workload independently when deployed.

## Autoscaling metrics

Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup.

## Testing

Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards.

## Change checklist

Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior.

## Known migration status

Redis realtime fanout and the PostgreSQL transactional-outbox → NATS JetStream durable-worker path are implemented as separate transports. Production NATS provisioning/credentials and additional domain-event migrations remain environment/domain-by-domain work rather than a platform gap.
