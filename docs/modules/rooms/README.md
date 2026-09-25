# Rooms

## Purpose

Owns room metadata, membership decisions, seats, chat state, current room request state, durable room versions/events, and authoritative room snapshots.

## Responsibilities

The module owns `rooms`, `room_participants`, `room_seat_states`, `room_member_requests`, `room_seat_applications`, `room_realtime_events`, `room_chat_messages`, `room_kickouts`, and Room Cricket state (`cricket_tournaments`, `cricket_matches`, `cricket_ball_events`). Routes validate input and delegate business decisions to services. Normal socket liveness is an expiring realtime Redis lease, not a PostgreSQL heartbeat.

## What this module owns

`rooms`, `room_participants`, `room_seat_states`, `room_member_requests`, `room_seat_applications`, `room_realtime_events`, `room_chat_messages`, `room_kickouts`, `cricket_tournaments`, `cricket_matches`, and `cricket_ball_events`.

## What this module does NOT own

This module does not own SFU transport state, edge routing, or client UI state.

## Source of truth

PostgreSQL is durable authority. Redis room leases, transport sequences, and replay buffers are ephemeral/rebuildable and never override PostgreSQL state.

## Important files

`apps/room-control-service/main.py`, `backend/app/services/rooms/room_action_service.py`, `backend/app/services/rooms/room_state_service.py`, `backend/app/services/rooms/room_db_context.py`, `backend/app/api/routes/room_realtime_commands.py`, and `docs/architecture/room-control-service.md`.

## Public API/contracts

room routes and WebSocket commands under /api/v1. Preserve deployed request and response shapes while migrating implementation.

## Events published

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database tables and state: `rooms, room_participants, room_seat_states, room_realtime_events, room_chat_messages, cricket_tournaments, cricket_matches, cricket_ball_events`.

## Redis keys/state owned

`funkey:realtime:room:*`, `funkey:realtime:gateway:user-rooms:*`, and `funkey:realtime:gateway:room-users:*` leases plus stream epoch/sequence, replay, command-dedupe, and fanout keys are transient. Media assignment is a separate Redis role.

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

Room Control is independently deployable as `funkey-room-control` on port 8085. Apply Alembic first, apply the service-local PostgreSQL role boundary, then roll out the Room Control image before directing core compatibility-proxy traffic to it. Core retains only the public compatibility proxy and explicit cross-domain room commerce/contribution orchestration.

## Change checklist

Before changing this module: identify the owning table and contract, add an additive migration if needed, preserve Flutter compatibility, verify permission checks, and document rollback.

## Known migration status

Chunk 20 Room State Engine v2 is implemented and Chunk 21 completed the one-Go-socket application realtime cutover. Chunk 26 physically extracts durable Room Control authority from core into `room-control-service`, preserves the public `/api/v1/rooms/**` contract through a compatibility proxy, isolates room PostgreSQL credentials, and keeps Go realtime/Redis/media transport outside Room Control authority.


## Flutter room presentation ownership

Client gift animation queues are not room-domain authority. Flying-gift and
premium-broadcast presentation state is scoped to the mounted
`LiveRoomGiftController` and disposed when that room exits. Durable gift,
wallet and room-event outcomes remain backend/canonical realtime authority.
Do not introduce static Flutter event buses for room presentation.


## Canonical room chat contract

Room chat is durable room state. The canonical REST/realtime command accepts
text messages with `text`, and image messages with `message_type="image"`,
`media_url`, and optional `content_type`; image messages do not require fake
placeholder text. The backend validates HTTP(S) image URLs and persists
`media_url` in `room_chat_messages`, while `metadata_json` carries
presentation metadata.

All client success UI must wait for the canonical chat command to succeed.
Room snapshots/realtime deltas publish `recent_messages`; Flutter must project
that canonical list into presentation models rather than maintain a second
durable chat authority.
