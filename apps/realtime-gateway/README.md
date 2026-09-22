# Realtime gateway

## Purpose

This Go deployable transports authorized realtime events to WebSocket clients. It is a migration foundation alongside the operational Python API, not a replacement for its room and business rules.

## Responsibilities

- Authenticate each connection and room subscription through the authoritative FastAPI endpoint.
- Keep bounded WebSocket send queues, enforce local and Redis backed command rates, and close slow consumers.
- Fan out trusted backend events from Redis to authorized local room subscribers or a target user's connections.
- Advertise short Redis leases for gateway nodes and user connections, expose health and metrics, and drain on SIGTERM.

## What this module owns

WebSocket connection lifecycle, in-process recipient indexes, transport backpressure, connection leases, and node drain state. Its in-memory indexes are delivery aids; clients must refetch canonical snapshots after reconnect.

## What this module does NOT own

Identity, token issuance, bans, room membership, seats, chat persistence, wallet value, media transport, or command authorization rules. Client messages cannot publish arbitrary events or mutate durable state. Durable commands continue through FastAPI until a domain contract and parity tests support migration.

## Source of truth

PostgreSQL through FastAPI remains authoritative for durable application state. FastAPI verifies connection and room access. Redis stores short-lived gateway routing metadata and transports ephemeral fanout. Missed PubSub messages are recovered by client snapshot refetch, not by assuming Redis PubSub is a durable queue.

## Important files

- `cmd/realtime-gateway/main.go`: process startup and SIGTERM drain.
- `internal/gateway/auth.go`: control-plane authorization client.
- `internal/gateway/server.go`: HTTP, WebSocket, Redis subscription, rate limit, and leases.
- `internal/gateway/hub.go`: bounded local fanout.
- `internal/gateway/events.go`: event envelope validation.

## Public API/contracts

- `GET /live`: process liveness only.
- `GET /ready`: rejects while draining or while Redis subscription/health is unavailable.
- `GET /metrics`: Prometheus text metrics.
- `GET /ws`: WebSocket upgrade. Native clients pass `Authorization: Bearer <token>`. Browser clients may pass `bearer.<token>` in `Sec-WebSocket-Protocol`; configure the edge to redact this header. The server selects `funkey.v1`, never the token.
- Client messages: `{"type":"subscribe","room_public_id":"..."}`, `unsubscribe`, and `ping`. Room IDs are limited to 32 ASCII letters, digits, underscores or hyphens to match the control-plane contract. Other commands return `unsupported_command`.
- The backend verification contract is `POST /api/v1/realtime/verify` with the same Bearer token and `{"requested_action":"connect"}` or `{"requested_action":"subscribe","room_public_id":"..."}`. A successful response is `{"allowed":true,"user_id":123}`. Denial uses a 4xx response or `allowed:false`. Every subscription is checked on entry; active connections and subscriptions are rechecked every five minutes.
- Backend event envelope: see `../../contracts/events/realtime-gateway-v1.schema.json`. The backend alone publishes to Redis channel `funkey:realtime:events`.

## Events published

None. This gateway delivers backend events and emits only WebSocket transport control messages: `connected`, `subscribed`, `pong`, `error`, `server.draining`, and `resync_required`.

## Events consumed

Versioned room or user scoped envelopes on `funkey:realtime:events`. Room events reach locally subscribed clients; user events reach local connections for that user. The gateway does not change payload meaning or persist it.

## Database tables/state owned

None.

## Redis keys/state owned

- `funkey:realtime:gateway:node:<node_id>`: expiring JSON node state and connection count.
- `funkey:realtime:gateway:user:<user_id>:<connection_id>`: expiring routing lease with node ID.
- `funkey:realtime:gateway:rate:<user_id>`: one-second command counter shared by replicas.

Leases expire after 60 seconds and refresh every 20 seconds. They are not an identity or room authority.

## Dependencies

Go 1.27, Redis/Valkey, and the FastAPI verification endpoint. The process needs network access to both; credentials belong in environment/secret injection. Use private service networking for the verification endpoint and Redis.

## Security considerations

The gateway rejects missing/invalid tokens before upgrading, uses a configured browser origin allowlist in production, never accepts client supplied user IDs, reauthorizes room subscriptions, and limits client frames to 16 KiB. Keep Redis publishing rights restricted to trusted backend services. Do not log tokens or expose Redis externally. The `/metrics` path should be reachable only from observability infrastructure.

## Failure modes

If FastAPI cannot verify, new connections/subscriptions fail closed and periodic reauthorization closes or revokes existing access. Authorization concurrency is capped at 512 in flight per pod and waits at most the request timeout. Room authorization changes can take up to five minutes to revoke without an explicit control-plane disconnect event; sensitive commands still pass through FastAPI. If Redis disconnects, readiness fails and new upgrades stop; existing clients may miss ephemeral events. On resubscription, the gateway sends `resync_required` so clients can refetch. Slow clients are closed when their 64-message outbound queue fills. A gateway crash loses only transport state. A planned drain rejects upgrades, sends `server.draining`, waits up to the configured deadline, then closes remaining connections.

## Retry/idempotency behavior

The Redis subscription retries after interruption. HTTP verification uses a bounded timeout and is not retried on behalf of the client. Events may be missed or repeated during reconnect; consumers should deduplicate by `event_id` and refetch snapshots. No value transfer or durable write is performed here.

## Scaling behavior

Replicas subscribe independently to the same Redis channel and deliver only to their own connected clients. Correctness does not require load-balancer sticky sessions. `REALTIME_MAX_CONNECTIONS` bounds each pod; measure actual memory, network, Redis ops, and fanout capacity before raising it. User and node leases make routing visible to operators, but PubSub currently broadcasts each backend event to every gateway replica.

## Autoscaling metrics

`funkey_realtime_connections`, accepted connections, auth denials, slow client closes, event receive/invalid counts, and Redis subscription health are exposed at `/metrics`. CPU, memory, network egress, and reconnect rates should also feed scaling decisions.

## Observability

Structured JSON logs avoid token values. Metrics expose connections, backpressure closures, auth denials, event validation failures, and Redis subscription state. Correlate backend event IDs through the delivered envelope. Distributed tracing of the full command path remains a later migration step.

## Local development

Start FastAPI and Redis, then from this directory run `go run ./cmd/realtime-gateway` with variables from `.env.example` in your shell. The gateway does not parse dotenv files itself. Verify `/live` and `/ready`; readiness requires an active Redis subscription.

## Testing

`go test ./...`, `go test -race ./...`, `go vet ./...`, and `go fmt ./...`. Tests cover authorization delegation, room/user routing, slow-client eviction, drain admission, and WebSocket fanout through a test Redis server.

## Deployment notes

Expose `/ws` through a WebSocket capable load balancer with a sufficient idle timeout. Use a preStop/SIGTERM drain budget longer than `REALTIME_DRAIN_TIMEOUT`. `/ready` must be the readiness probe and `/live` the liveness probe. Redis PubSub and leases use a shared, highly available Redis/Valkey primary; do not point this process at an unrelated per-pod Redis.

## Change checklist

Check Python verification contract parity, client reconnect/snapshot behavior, Redis key compatibility, backpressure, origin configuration, tests/race/vet, metrics, and drain timing before routing production traffic here.

## Known migration status

FOUNDATION READY. Existing Flutter and Python realtime paths remain active until explicit traffic routing, contract parity, and rollback checks are complete.
