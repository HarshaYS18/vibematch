# Realtime Gateway

## Purpose

Provides FunKey's single authenticated application WebSocket while deferring all durable business decisions to FastAPI/domain authority. Mediasoup/WebRTC signaling is a separate media-plane connection.

## Responsibilities

- connection lifecycle using short-lived signed connect capabilities;
- locally verified room-specific subscribe capabilities;
- user/users/staff/all/room event routing;
- sharded transient recipient indexes;
- bounded priority backpressure and dedupe;
- Chunk 20 room replay/resume;
- allowlisted command relay to FastAPI;
- gateway/user/room leases;
- readiness, metrics, tracing, and drain.

## What this module owns

Ephemeral realtime transport only. It owns live sockets, routing indexes, delivery queues, replay delivery, leases, rate limits, and node drain state.

## What this module does NOT own

Identity, bans, roles, room membership, seats, chat persistence, Inbox membership, wallet/economy value, gifts, notifications, Watch Party truth, game truth, or media transport. The Go gateway never performs a durable business mutation itself.

## Source of truth

PostgreSQL-backed domain services remain authoritative. Identity/API issues short-lived signed realtime capabilities; Go verifies those grants locally. Redis/Valkey contains ephemeral fanout, leases, rate/idempotency metadata, and bounded room replay state.

## Important files

- `apps/realtime-gateway/README.md`
- `apps/realtime-gateway/internal/gateway/server.go`
- `apps/realtime-gateway/internal/gateway/hub.go`
- `apps/realtime-gateway/internal/gateway/commands.go`
- `backend/app/api/routes/realtime_gateway_auth.py`
- `backend/app/services/realtime_command_service.py`
- `frontend/vibematch_app/lib/realtime/app_realtime_hub.dart`
- `contracts/events/realtime-gateway-v2.schema.json`

## Public API/contracts

Go:
- `GET /ws`
- `GET /live`
- `GET /ready`
- `GET /metrics`

Control plane:
- capability mint/public-key endpoints for connect and room grants
- `POST /api/v1/realtime/command` for authoritative command relay
- `/api/v1/realtime/verify` exists only as rollback/diagnostic compatibility and is not the normal hot path

The WebSocket protocol is `funkey.v2`. Browser-compatible authentication uses `bearer.<token>` as an additional offered subprotocol; only `funkey.v2` is selected.

## Events consumed

The gateway consumes versioned backend envelopes from `funkey:realtime:events` with `room`, `user`, `users`, `staff`, or `all` scope.

Chunk 20 room traffic carries an ephemeral contiguous transport stream/sequence and bounded replay window before authoritative snapshot fallback.

## Commands

Client commands are strictly allowlisted. The gateway forwards commands to the owning backend control/domain boundary and returns transport acknowledgements/errors. Domain services own permission checks, idempotency, durable writes, and resulting event publication.

## Database tables/state owned

None.

## Redis keys/state

Gateway/user/rate keys under `funkey:realtime:gateway:*` plus room leases and Chunk 20 replay keys under `funkey:realtime:room:*`. All expire and are non-authoritative.

## Failure modes

- Redis down: readiness fails; reconnect/resync is required.
- capability public-key/issuance path unavailable: new/renewed grants fail closed while already-valid grants remain bounded by expiry.
- owning command service unavailable: command errors; no local mutation.
- replay discontinuity: client refreshes authoritative room snapshot.
- slow consumer: best-effort traffic drops first; required-overflow client closes.
- planned drain: upgrades stop and clients reconnect to healthy replicas.

## Security considerations

Never trust client-supplied identity or staff status. Keep commands allowlisted, frames/rates/queues/concurrency bounded, tokens out of logs, Redis private, and browser origins allowlisted.

## Testing

Run `gofmt`, `go vet ./...`, `go test ./...`, and `go test -race ./...` plus repository architecture/contract/Flutter/backend/media/infrastructure CI.

## Known migration status

**Chunk 21 application-socket cutover is implemented.** Flutter uses one Go application WebSocket. Legacy FastAPI Inbox/room WebSocket routes and feature-owned application sockets are retired. Mediasoup signaling remains separate by design.
