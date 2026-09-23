# Realtime Gateway

## Purpose

Provides FunKey's single authenticated application WebSocket while deferring all durable business decisions to FastAPI/domain authority. Mediasoup/WebRTC signaling is a separate media-plane connection.

## Responsibilities

- connection lifecycle and reauthorization;
- authorized room subscriptions;
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

PostgreSQL-backed FastAPI/domain services remain authoritative. Redis/Valkey contains ephemeral fanout, leases, rate/idempotency metadata, and bounded room replay state.

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

FastAPI control plane:
- `POST /api/v1/realtime/verify`
- `POST /api/v1/realtime/command`

The WebSocket protocol is `funkey.v2`. Browser-compatible authentication uses `bearer.<token>` as an additional offered subprotocol; only `funkey.v2` is selected.

## Events consumed

The gateway consumes versioned backend envelopes from `funkey:realtime:events` with `room`, `user`, `users`, `staff`, or `all` scope.

Chunk 20 room traffic carries an ephemeral contiguous transport stream/sequence and bounded replay window before authoritative snapshot fallback.

## Commands

Client commands are strictly allowlisted. The gateway forwards authenticated commands to FastAPI and returns transport acknowledgements/errors. FastAPI owns permission checks, idempotency, durable writes, and resulting domain-event publication.

## Database tables/state owned

None.

## Redis keys/state

Gateway/user/rate keys under `funkey:realtime:gateway:*` plus room leases and Chunk 20 replay keys under `funkey:realtime:room:*`. All expire and are non-authoritative.

## Failure modes

- Redis down: readiness fails; reconnect/resync is required.
- FastAPI verify down: new connect/subscribe fails closed.
- FastAPI command down: command errors; no local mutation.
- replay discontinuity: client refreshes authoritative room snapshot.
- slow consumer: best-effort traffic drops first; required-overflow client closes.
- planned drain: upgrades stop and clients reconnect to healthy replicas.

## Security considerations

Never trust client-supplied identity or staff status. Keep commands allowlisted, frames/rates/queues/concurrency bounded, tokens out of logs, Redis private, and browser origins allowlisted.

## Testing

Run `gofmt`, `go vet ./...`, `go test ./...`, and `go test -race ./...` plus repository architecture/contract/Flutter/backend/media/infrastructure CI.

## Known migration status

**Chunk 21 application-socket cutover is implemented.** Flutter uses one Go application WebSocket. Legacy FastAPI Inbox/room WebSocket routes and feature-owned application sockets are retired. Mediasoup signaling remains separate by design.
