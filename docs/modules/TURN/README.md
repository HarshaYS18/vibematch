# TURN

## Purpose

Relays WebRTC traffic when direct peer/SFU paths cannot connect.

## Responsibilities

coturn relay and credentials; no room authorization or SFU state.

## What this module owns

coturn relay and credentials; no room authorization or SFU state.

## What this module does NOT own

This module does not take over an adjacent domain merely because it transports or caches its data.

## Source of truth

PostgreSQL remains the durable source of truth for application state.

## Important files

`infra/turn/turnserver.conf`, `infra/turn/docker-compose.yml`.

## Public API/contracts

STUN/TURN on deployment ports; ICE credentials supplied to clients. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database: None.

## Redis keys/state owned

None as application authority.

## Dependencies

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable.

## Security considerations

Use time-limited credentials, TLS where supported, and rate limits to prevent open relay abuse. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes

TURN outage affects restricted networks; verify TURN-only call before declaring media healthy.

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

Local TURN configuration exists; production networking and credentials are external.
