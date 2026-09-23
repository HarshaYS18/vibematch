# Rooms

## Purpose

Owns room metadata, membership decisions, seats, chat state, current room request state, durable room versions/events, and authoritative room snapshots.

## Responsibilities

The module owns `rooms`, `room_participants`, `room_seat_states`, `room_member_requests`, `room_seat_applications`, `room_realtime_events`, `room_chat_messages`, and `room_kickouts`. Routes validate input and delegate business decisions to services. Normal socket liveness is an expiring realtime Redis lease, not a PostgreSQL heartbeat.

## What this module owns

`rooms`, `room_participants`, `room_seat_states`, `room_member_requests`, `room_seat_applications`, `room_realtime_events`, `room_chat_messages`, and `room_kickouts`.

## What this module does NOT own

This module does not own SFU transport state, edge routing, or client UI state.

## Source of truth

PostgreSQL is durable authority. Redis room leases, transport sequences, and replay buffers are ephemeral/rebuildable and never override PostgreSQL state.

## Important files

`backend/app/services/rooms/room_action_service.py`, `backend/app/services/rooms/room_state_service.py`, `backend/app/api/routes/room_realtime.py`, `backend/app/realtime/connection_manager.py`, and `docs/architecture/room-state-engine-v2.md`.

## Public API/contracts

room routes and WebSocket commands under /api/v1. Preserve deployed request and response shapes while migrating implementation.

## Events published

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database tables and state: `rooms, room_participants, room_seat_states, room_realtime_events, room_chat_messages`.

## Redis keys/state owned

`funkey:realtime:room:*` leases, stream epoch/sequence, replay, command-dedupe, and fanout keys are transient. Media assignment is a separate Redis role.

## Dependencies

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services.

## Security considerations

Room privacy, kick, membership, seat, and mic policy are checked in FastAPI. Never log tokens, OTPs, or payment secrets.

## Failure modes

Clients first attempt bounded contiguous room replay. If the stream epoch changed, replay is trimmed/unavailable, or Redis sequencing fails, they refetch the versioned authoritative room snapshot.

## Retry/idempotency behavior

Reads and writes should use bounded timeouts. Retries are safe only for read operations or writes backed by an idempotency key and known commit outcome.

## Scaling behavior

Scale stateless API replicas only within the PostgreSQL connection budget.

## Autoscaling metrics

Track route request rate, p95 latency, error rate, transaction latency, DB pool use, and domain-specific rejection counts. Trace commands through commit and fanout with a request ID; avoid user PII in metric labels.

## Observability

Trace commands through commit and fanout with a request ID; avoid user PII in metric labels.

## Local development

Start dependencies with `.\\scripts\\dev-up.ps1`, then run affected backend tests with `python -m unittest discover -s backend/tests -p test_*.py` from the repository root with the backend import path configured, or use the test command in the root README.

## Testing

Add a regression test for authorization, transaction outcome, and duplicate/reconnect behavior when relevant.

## Deployment notes

Apply Alembic first; roll out compatible API behavior; check readiness and error metrics.

## Change checklist

Before changing this module: identify the owning table and contract, add an additive migration if needed, preserve Flutter compatibility, verify permission checks, and document rollback.

## Known migration status

Chunk 20 Room State Engine v2 is implemented: snapshot reads are side-effect free, periodic room DB heartbeat is removed, current membership/seat request state has dedicated tables, durable room/event versions are explicit, and bounded Redis replay falls back to snapshots. Legacy FastAPI room-socket replacement payloads remain during migration; Chunk 21 owns the one-Go-socket cutover.
