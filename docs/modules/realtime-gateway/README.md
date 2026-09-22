# Realtime Gateway

## Purpose and responsibilities

Manages WebSocket transport, reconnect, fanout, and drain while deferring durable decisions to FastAPI domain authority. Connection lifecycle and transient routing metadata; no room, seat, role, or wallet authority.

## Ownership and source of truth

PostgreSQL remains the durable source of truth for application state. This module does not take over an adjacent domain merely because it transports or caches its data. Refer to the source-of-truth architecture before changing ownership.

## Important files and public contracts

`apps/realtime-gateway/README.md`, `apps/realtime-gateway/internal/gateway/server.go`, `backend/app/realtime/event_bus.py`, `backend/app/api/routes/realtime_gateway_auth.py`. Contract surface: Go `GET /ws`, `/live`, `/ready`, `/metrics`; backend `POST /api/v1/realtime/verify`. The gateway remains a foundation/shadow path until client migration and parity checks. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published and consumed

The Go gateway consumes backend-published, versioned envelopes from Redis channel `funkey:realtime:events` and delivers them to authorized local sockets. It does not publish domain events or make durable commands. Redis Pub/Sub is ephemeral; after reconnect, the client must refetch the authoritative snapshot. This is distinct from durable JetStream work delivery.

## Database and Redis state

Database: No gateway-owned durable tables; room_realtime_events remain authoritative replay data. Redis/Valkey: Future TTL connection routing/presence and drain flags; process memory holds only live sockets.

## Dependencies and security

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable. Authenticate every connection and command; bound message sizes and outbound queues. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes and retry/idempotency

On pod drain, reject upgrades and direct reconnect; clients reload snapshot after gaps. Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling and autoscaling metrics

Scale this workload independently when deployed. Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development and testing

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup. Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes and change checklist

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards. Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior. Known migration status: **Go gateway foundation/shadow; Flutter traffic migration not complete.**
