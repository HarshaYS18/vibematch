# Core API

## Purpose and responsibilities

Serves HTTP business contracts and durable commands during the migration. Current FastAPI application in backend/app; Go core-api target is bounded and not an authority by default.

## Ownership and source of truth

PostgreSQL remains the durable source of truth for application state. This module does not take over an adjacent domain merely because it transports or caches its data. Refer to the source-of-truth architecture before changing ownership.

## Important files and public contracts

`backend/app/main.py`, `backend/app/api/router.py`, `backend/app/database.py`. Contract surface: /api/v1/*, /health; verify /live and /ready per deployed version. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published and consumed

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Database and Redis state

Database: Domain tables reached by SQLAlchemy services. Redis/Valkey: Redis fanout, rate limiting, media registry; no in-process session authority.

## Dependencies and security

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable. JWT verification, request limits, CORS, and domain authorization are required before writes. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes and retry/idempotency

DB exhaustion or schema mismatch should remove readiness; liveness must remain process-only. Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling and autoscaling metrics

Scale this workload independently when deployed. Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development and testing

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup. Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes and change checklist

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards. Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior. Known migration status: **FastAPI active; Go core API is a strangler target.**
