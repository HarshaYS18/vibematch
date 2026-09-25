# Media

## Purpose

Runs the canonical Socket.IO and mediasoup SFU for audio/video transport.

## Responsibilities

Routers, transports, producers, consumers, and RTP lifecycle only.

## What this module owns

Routers, transports, producers, consumers, and RTP lifecycle only.

## What this module does NOT own

This module does not take over an adjacent domain merely because it transports or caches its data.

## Source of truth

FastAPI remains authoritative for identity, room membership, seats, calls, and permissions.

## Important files

`backend_media/src/server.ts`, `backend_media/src/mediasoup/roomManager.ts`, `backend_media/src/control/heartbeatLoop.ts`.

## Public API/contracts

Socket.IO signaling, /health, /ready; backend media discovery and verify endpoints. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database: No application-state tables; call and room authority remains in FastAPI.

## Redis keys/state owned

Node heartbeat, drain flag, capacity reservation, sticky room assignment in dedicated media Redis.

## Dependencies

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable.

## Security considerations

Every sensitive action reauthorizes through FastAPI; clients cannot select node or supply trusted roles. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes

Registry heartbeat loss makes media unready; re-resolve after node loss and follow drain runbook.

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

Canonical TypeScript media plane active; scaling requires network-specific validation.


## Flutter room-media resource lifecycle

Chunk 34-M9 does not create a second media engine. Flutter's existing
`LiveRoomMediaSignalingService` remains the owner of the single
`RoomMediaEngine`, while `RoomMediaResourceParticipant` exposes that engine
to the authenticated AppShell's foundation resource registry.

Foreground recovery calls `RoomMediaEngine.reconnect()`; background and
memory-pressure events do not tear down active transports. Authenticated-session
release calls `leave()` rather than terminal `dispose()`, because the engine
is held by a reusable compatibility singleton.

Registration follows actual room media configure/leave lifetime so minimized
rooms remain lifecycle-managed even if their route widget is disposed. Durable
room membership, seats and permissions remain FastAPI/`RoomSessionRepository`
authority.


## Public media-control discovery

Chunk 35 routes new client room-media discovery through the dedicated
`media.funkey.com` control surface:

`/api/v1/media-control/rooms/{room_public_id}/assignment`.

This hostname is control/discovery only. It does not expose the whole API,
media-node internal heartbeat/drain endpoints, RTP, TURN, or arbitrary uploads.
The legacy API-host assignment path remains temporarily for compatibility.
