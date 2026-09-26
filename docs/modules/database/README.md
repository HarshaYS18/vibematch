# Database

## Purpose

Holds durable application truth and provides bounded SQLAlchemy connections.

## Responsibilities

PostgreSQL schema and transaction boundaries, not WebSocket sockets or SFU state.

## What this module owns

PostgreSQL schema and transaction boundaries, not WebSocket sockets or SFU state.

## What this module does NOT own

This module does not take over an adjacent domain merely because it transports or caches its data.

## Source of truth

PostgreSQL remains the durable source of truth for application state.

## Important files

`backend/app/database.py`, `backend/alembic/env.py`, `backend/alembic/versions`, `deploy/postgres`, `infra/postgres`, and `docs/architecture/postgresql-platform.md`.

## Public API/contracts

SQLAlchemy sessions internally; Alembic graph for schema evolution. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database: All durable domain tables; single canonical migration graph.

## Redis keys/state owned

No Redis role in durable schema ownership.

## Dependencies

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable.

## Security considerations

Pool maximums, PgBouncer client/server budgets, direct migration credentials, SQL timeouts, least privilege, and backups are critical. Transaction-pooled code must not depend on arbitrary session state. Do not log tokens, credentials, raw SQL parameters, private content, or payment secrets.

## Failure modes

If primary fails, halt unsafe writes; restore or fail over using tested recovery.

## Retry/idempotency behavior

Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling behavior

Scale this workload independently when deployed.

## Autoscaling metrics

Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Track SQLAlchemy pool saturation, privacy-safe slow-query fingerprints, PostgreSQL connection usage, deadlocks, lock counts, long-running transactions, and pg_stat_statements query IDs. Pair alerts with the matching runbook.

## Local development

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup.

## Testing

Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards.

## Change checklist

Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior.

## Known migration status

PostgreSQL is active. Chunk 18 adds bounded transaction PgBouncer manifests, direct migration DSN separation, client/server connection-budget validation, pg_stat_statements bootstrap/observer contracts, and future per-service credential/schema policy. Provider-specific production endpoints, secrets, limits, backups, and extension enablement remain environment prerequisites.
