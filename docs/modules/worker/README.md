# Worker

## Purpose

Processes durable asynchronous side effects such as notifications or post-processing.

## Responsibilities

Consumer execution, retries, dead-letter handling, and idempotency state; domain DB commits remain with owners.

## What this module owns

Consumer execution, retries, dead-letter handling, and idempotency state; domain DB commits remain with owners.

## What this module does NOT own

This module does not take over an adjacent domain merely because it transports or caches its data.

## Source of truth

PostgreSQL remains the durable source of truth for application state.

## Important files

`apps/worker/main.py`, `apps/worker/events.py`, `apps/worker/handlers.py`, `backend/app/services/event_outbox_service.py`, `backend/app/services/outbox_relay_service.py`, and `contracts/events/`.

## Public API/contracts

No public HTTP business API. The worker consumes the versioned JetStream envelope and exposes only operational `/live`, `/ready`, and `/metrics` endpoints.

## Events published

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Events consumed

The deployable owns a durable JetStream pull consumer for implemented event contracts. It acknowledges only after successful idempotent handling, uses bounded redelivery, and publishes terminal failures to the dead-letter stream before acknowledging the source.

## Database tables/state owned

Database: Handler-specific records and durable idempotency/outbox state where introduced.

## Redis keys/state owned

May use short leases and rate limits; not sole record of delivery outcome.

## Dependencies

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable.

## Security considerations

Never retry wallet/value movement without stable idempotency key. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes

Broker outage creates backlog; stop consuming on drain, finish or safely return in-flight work.

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

Deployable implemented. PostgreSQL transactional-outbox claims, JetStream publication, durable notification consumption, idempotency, bounded retry/dead-letter handling, health/metrics and graceful shutdown are present. Production broker endpoints/credentials and measured scaling thresholds remain environment inputs.
