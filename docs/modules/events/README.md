# Events

## Purpose and responsibilities

Defines versioned domain event envelopes and asynchronous delivery boundaries. Event contracts and broker delivery; not synchronous business authorization.

## Ownership and source of truth

PostgreSQL remains the durable source of truth for application state. This module does not take over an adjacent domain merely because it transports or caches its data. Refer to the source-of-truth architecture before changing ownership.

## Important files and public contracts

`backend/app/realtime/events.py`, `backend/app/realtime/event_bus.py`, `contracts/events (target)`. Contract surface: Existing room event names; NATS JetStream envelope is the selected target. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published and consumed

NATS JetStream is the selected broker. Contracts must carry event_id, event_type, event_version, occurred_at, request_id, trace_id, actor_user_id, and payload. The broker is at-least-once; consumers deduplicate.

## Database and Redis state

Database: No direct tables unless transactional outbox/inbox records are added. Redis/Valkey: Transport coordination and dedupe leases may be transient.

## Dependencies and security

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable. Never place secrets or unnecessary PII in payloads; authorize consumers. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes and retry/idempotency

At-least-once delivery requires idempotent handlers, bounded retries, and dead-letter inspection. Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling and autoscaling metrics

Scale this workload independently when deployed. Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development and testing

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup. Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes and change checklist

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards. Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior. Known migration status: **Existing Redis realtime bus; NATS JetStream foundation is being introduced.**
