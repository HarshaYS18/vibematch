# Rooms

## Purpose

Owns room metadata, membership decisions, seats, chat state, and room snapshots.

## Responsibilities

The module owns rooms, room_participants, room_seat_states, room_realtime_events, room_chat_messages, room_kickouts. Routes should validate input and delegate business decisions to services.

## What this module owns

rooms, room_participants, room_seat_states, room_realtime_events, room_chat_messages, room_kickouts.

## What this module does NOT own

This module does not own SFU transport state, edge routing, or client UI state.

## Source of truth

PostgreSQL is the durable source of truth for rooms, room_participants, room_seat_states, room_realtime_events, room_chat_messages.

## Important files

`backend/app/services/rooms/room_action_service.py`, `backend/app/services/rooms/room_state_service.py`, `backend/app/api/routes/room_realtime.py`.

## Public API/contracts

room routes and WebSocket commands under /api/v1. Preserve deployed request and response shapes while migrating implementation.

## Events published

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database tables and state: `rooms, room_participants, room_seat_states, room_realtime_events, room_chat_messages`.

## Redis keys/state owned

Room fanout coordination and media assignment are transient Redis uses.

## Dependencies

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services.

## Security considerations

Room privacy, kick, membership, seat, and mic policy are checked in FastAPI. Never log tokens, OTPs, or payment secrets.

## Failure modes

Clients missing an event must refetch the versioned room snapshot.

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

Existing FastAPI authority; gateway transport migration is planned.
