# Worker

## Purpose and responsibilities

Processes durable asynchronous side effects such as notifications or post-processing. Consumer execution, retries, dead-letter handling, and idempotency state; domain DB commits remain with owners.

## Ownership and source of truth

PostgreSQL remains the durable source of truth for application state. This module does not take over an adjacent domain merely because it transports or caches its data. Refer to the source-of-truth architecture before changing ownership.

## Important files and public contracts

`backend/app/services/push_notification_service.py`, `backend/app/services/notification_service.py`, `contracts/events (target)`. Contract surface: No public HTTP business API; broker envelope and handler contract are planned. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published and consumed

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Database and Redis state

Database: Handler-specific records and durable idempotency/outbox state where introduced. Redis/Valkey: May use short leases and rate limits; not sole record of delivery outcome.

## Dependencies and security

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable. Never retry wallet/value movement without stable idempotency key. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes and retry/idempotency

Broker outage creates backlog; stop consuming on drain, finish or safely return in-flight work. Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling and autoscaling metrics

Scale this workload independently when deployed. Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development and testing

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup. Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes and change checklist

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards. Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior. Known migration status: **Foundation target; assess actual worker deployable before enabling consumers.**
