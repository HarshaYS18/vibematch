# Media

## Purpose and responsibilities

Runs the canonical Socket.IO and mediasoup SFU for audio/video transport. Routers, transports, producers, consumers, and RTP lifecycle only.

## Ownership and source of truth

FastAPI remains authoritative for identity, room membership, seats, calls, and permissions. This module does not take over an adjacent domain merely because it transports or caches its data. Refer to the source-of-truth architecture before changing ownership.

## Important files and public contracts

`backend_media/src/server.ts`, `backend_media/src/mediasoup/roomManager.ts`, `backend_media/src/control/heartbeatLoop.ts`. Contract surface: Socket.IO signaling, /health, /ready; backend media discovery and verify endpoints. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published and consumed

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Database and Redis state

Database: No application-state tables; call and room authority remains in FastAPI. Redis/Valkey: Node heartbeat, drain flag, capacity reservation, sticky room assignment in dedicated media Redis.

## Dependencies and security

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable. Every sensitive action reauthorizes through FastAPI; clients cannot select node or supply trusted roles. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes and retry/idempotency

Registry heartbeat loss makes media unready; re-resolve after node loss and follow drain runbook. Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling and autoscaling metrics

Scale this workload independently when deployed. Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development and testing

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup. Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes and change checklist

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards. Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior. Known migration status: **Canonical TypeScript media plane active; scaling requires network-specific validation.**
