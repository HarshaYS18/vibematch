# Realtime Gateway

## Purpose

Manages WebSocket transport, reconnect, fanout, and drain while deferring durable decisions to FastAPI domain authority.

## Responsibilities

Connection lifecycle and transient routing metadata; no room, seat, role, or wallet authority.

## What this module owns

Connection lifecycle and transient routing metadata; no room, seat, role, or wallet authority.

## What this module does NOT own

The gateway does not own identity, bans, room membership, seats, chat persistence, wallet value, media transport, or durable command authorization.

## Source of truth

PostgreSQL remains the durable source of truth for application state.

## Important files

`apps/realtime-gateway/README.md`, `apps/realtime-gateway/internal/gateway/server.go`, `backend/app/realtime/event_bus.py`, `backend/app/api/routes/realtime_gateway_auth.py`.

## Public API/contracts

Go `GET /ws`, `/live`, `/ready`, `/metrics`; backend `POST /api/v1/realtime/verify`. The gateway implements the production transport contract; traffic cutover remains controlled by deployment/client compatibility. Existing FastAPI compatibility paths stay available until the client migration is explicitly completed.

## Events published

No domain events. The gateway sends WebSocket transport controls only; durable commands remain with FastAPI.

## Events consumed

The Go gateway consumes backend-published, versioned envelopes from Redis channel `funkey:realtime:events` and delivers them to authorized local sockets. It does not publish domain events or make durable commands. Redis Pub/Sub is ephemeral; after reconnect, the client must refetch the authoritative snapshot. This is distinct from durable JetStream work delivery.

## Database tables/state owned

Database: No gateway-owned durable tables; room_realtime_events remain authoritative replay data.

## Redis keys/state owned

`funkey:realtime:gateway:node:<node_id>`, `funkey:realtime:gateway:user:<user_id>:<connection_id>`, and `funkey:realtime:gateway:rate:<user_id>` are expiring routing and rate-limit keys. Process memory holds only live sockets and recipient indexes.

## Dependencies

Depends on Go, Redis/Valkey, and the FastAPI `POST /api/v1/realtime/verify` endpoint. FastAPI owns PostgreSQL access for authorization; the gateway has no direct database pool.

## Security considerations

Authenticate every connection and command; bound message sizes and outbound queues. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes

On pod drain, reject upgrades and direct reconnect; clients reload snapshot after gaps.

## Retry/idempotency behavior

Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling behavior

Scale this workload independently when deployed.

## Autoscaling metrics

Measure active WebSockets (`funkey_realtime_connections`), accepted connections, auth denials, slow-client closes, Redis subscription health, CPU, memory, network egress, queue/backpressure, and reconnect rate. Drain before scale-in.

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

Transport implementation complete: bounded queues, connection/device budgets, authorization revalidation, subscription authorization, Redis cross-instance fanout, event dedupe, leases, reconnect/resync controls, metrics and graceful drain are implemented. Client traffic cutover is a deployment decision, not a missing gateway feature.
