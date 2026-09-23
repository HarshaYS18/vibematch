# Realtime gateway

## Purpose

The Go realtime gateway is FunKey's single authenticated **application realtime transport**. Every non-media realtime feature shares one WebSocket at `GET /ws`. Mediasoup/WebRTC signaling remains a separate media-plane connection.

The gateway is transport infrastructure, not a business authority. PostgreSQL-backed FastAPI/domain services remain authoritative for identity, rooms, moderation, Inbox persistence, wallet/economy value, gifts, notifications, and every durable mutation.

## Responsibilities

- Authenticate each connection through the authoritative FastAPI control plane.
- Authorize every room subscription and periodically re-authorize active access.
- Route backend events with `room`, `user`, `users`, `staff`, or `all` scope.
- Maintain sharded in-process room/user recipient indexes.
- Enforce connection budgets, frame/rate limits, bounded priority queues, slow-consumer eviction, and bounded event deduplication.
- Resume Chunk 20 room streams from the bounded Redis replay window when continuity is provable; otherwise require snapshot resync.
- Relay only explicitly allowlisted client commands to FastAPI using the caller's authenticated bearer token.
- Maintain expiring gateway/user/room presence leases.
- Expose health, readiness, metrics, tracing, and graceful drain behavior.

## What this module owns

WebSocket connection lifecycle, transport authentication state, recipient indexes, delivery priority/backpressure, bounded transport replay, connection/presence leases, rate limits, node drain state, and transport metrics.

These are ephemeral delivery aids. They are never durable application truth.

## What this module does NOT own

The gateway does not own:

- identity, sessions, bans, roles, or permissions;
- room membership, seats, chat persistence, room settings, Watch Party state, or game state;
- Inbox conversation membership or message/read authority;
- wallet balances, gifts, purchases, or ledger value;
- notification persistence;
- media producers/consumers, SFU state, or WebRTC negotiation.

Allowlisted client commands are forwarded to FastAPI. FastAPI re-validates the authenticated user and executes the existing authoritative domain service before publishing resulting events back through the canonical realtime channel.

## Source of truth

PostgreSQL through FastAPI/domain services remains authoritative for durable state.

Redis/Valkey is used for ephemeral transport state:

- pub/sub fanout;
- short-lived gateway/user/room leases;
- command rate counters and idempotency claims;
- bounded Chunk 20 room replay streams and transport sequence/epoch state.

Redis Pub/Sub is not treated as durable delivery. Clients recover application truth through authoritative REST snapshots when replay continuity cannot be proven.

## Important files

- `cmd/realtime-gateway/main.go`: process startup and SIGTERM drain.
- `internal/gateway/auth.go`: FastAPI connection/subscription verification client.
- `internal/gateway/commands.go`: allowlisted FastAPI command relay.
- `internal/gateway/server.go`: WebSocket protocol, room replay, leases, rate limits, Redis consumer, drain.
- `internal/gateway/hub.go`: sharded recipient indexes, bounded priority queues, dedupe, fanout.
- `internal/gateway/events.go`: v2 backend event envelope validation.
- `../../contracts/events/realtime-gateway-v2.schema.json`: canonical event contract.
- `../../backend/app/api/routes/realtime_gateway_auth.py`: authoritative verify/command control-plane endpoints.
- `../../backend/app/services/realtime_command_service.py`: authoritative application command dispatch.

## Public API/contracts

### Gateway HTTP

- `GET /live`: process liveness only.
- `GET /ready`: fails while draining, Redis is unavailable, or the canonical Redis subscription is down.
- `GET /metrics`: Prometheus text metrics.
- `GET /ws`: the single application WebSocket.

### WebSocket authentication

Native clients may send `Authorization: Bearer <token>`.

Browser-compatible clients use subprotocols:

- `funkey.v2`
- `bearer.<access-token>`

The server selects `funkey.v2`; it never echoes the bearer-token subprotocol. Edge access logs must redact `Sec-WebSocket-Protocol` because it may carry a bearer token.

### Transport commands

- `{"type":"ping"}`
- `{"type":"subscribe","room_public_id":"ROOM1"}`
- `{"type":"subscribe","room_public_id":"ROOM1","stream":"room:ROOM1:<epoch>","last_sequence":42}`
- `{"type":"unsubscribe","room_public_id":"ROOM1"}`

A successful room subscription returns `subscribed` plus replay/resync metadata. If the supplied stream cursor cannot be proven contiguous, `resync_required=true` and the client refreshes `RoomSessionRepository` from the authoritative snapshot.

### Application commands

The gateway accepts only commands in the compiled allowlist. Inbox and room commands are relayed to `POST /api/v1/realtime/command`; arbitrary client event publication is impossible.

Examples include:

- Inbox typing/activity/mark-read hints;
- room membership/seat/moderation/settings/chat commands;
- Watch Party and room-activity commands;
- room-music control events.

FastAPI performs all business authorization and durable mutations. A command produces `command/ack` or `command/error`; resulting domain state is delivered as normal backend-published events.

### FastAPI control plane

- `POST /api/v1/realtime/verify`
- `POST /api/v1/realtime/command`

Verification responses include the authenticated `user_id` and server-derived `is_staff`; the gateway never trusts client-supplied identity or staff flags.

## Backend event contract

Trusted backend services publish versioned envelopes to:

`funkey:realtime:events`

Supported scopes:

- `room`
- `user`
- `users`
- `staff`
- `all`

The gateway validates routing metadata and treats domain payloads as opaque.

## Delivery priority and backpressure

Per-client delivery is bounded and prioritized:

1. `critical`: session/security/revocation/resync/control events;
2. `normal`: durable-domain changes, room deltas, Inbox messages, wallet/gift/notification updates;
3. `best_effort`: typing/activity/presence hints.

When the queue is full, best-effort traffic may be dropped. Critical traffic may evict lower-priority queued work. A client that cannot accept required normal/critical traffic is closed and must reconnect/resync.

No unbounded application socket queue is allowed.

## Room recovery

Chunk 20 room events carry a transport stream:

`room:<room_public_id>:<epoch>`

with a contiguous transport `sequence`.

On reconnect:

1. Flutter re-subscribes with its last stream/sequence cursor.
2. Go verifies room access through FastAPI.
3. Go reads the bounded Redis replay stream.
4. If every missing sequence is present and the epoch matches, Go replays it.
5. Otherwise Go returns `resync_required=true`.
6. Flutter refreshes the authoritative room snapshot and resumes from the new cursor.

The transport sequence is not the durable PostgreSQL room `event_sequence`.

## Redis keys/state owned or consumed

Gateway-owned/maintained:

- `funkey:realtime:gateway:node:<node_id>`
- `funkey:realtime:gateway:user:<user_id>:<connection_id>`
- `funkey:realtime:gateway:user-active:<user_id>`
- `funkey:realtime:gateway:rate:<user_id>`

Room transport compatibility/state:

- `funkey:realtime:room:leases:<room_id>:<user_id>`
- Chunk 20 room stream epoch/sequence/replay keys under `funkey:realtime:room:*`

All are expiring transport state, not business authority.

## Security considerations

- Connection and room access fail closed when FastAPI verification is unavailable.
- Browser origins are allowlisted in production.
- The gateway never accepts client-supplied user/staff identity.
- Commands are compile-time allowlisted and re-authorized by FastAPI.
- Frames, command rates, connections, per-user devices, auth concurrency, command concurrency, replay windows, queues, and dedupe memory are bounded.
- Tokens are never logged.
- Redis publishing rights must be restricted to trusted backend services.
- `/metrics` should be limited to observability infrastructure.

## Failure modes

### Redis interruption

Readiness fails and new upgrades stop. Connected clients can miss ephemeral Pub/Sub traffic. When the consumer recovers, clients receive `resync_required`; room clients attempt bounded replay or fetch authoritative snapshots.

### FastAPI verification failure

New connections/subscriptions fail closed. Periodic reauthorization closes invalid sessions or revokes room subscriptions.

### FastAPI command failure

The gateway returns `command/error`. It does not locally apply the requested business mutation.

### Slow client

Best-effort events are dropped first. If required traffic still cannot fit, the client is closed and reconnects/resyncs.

### Gateway crash

Only ephemeral transport state is lost. Durable application state remains in PostgreSQL/domain stores.

## Retry/idempotency behavior

HTTP verification uses bounded timeouts.

Room command forwarding supports stable `command_id` claims in FastAPI/Redis so duplicate retries do not blindly repeat authoritative mutations. Transient PostgreSQL lock/deadlock/serialization failures receive a small bounded retry budget in the FastAPI command service.

Clients must still reconcile authoritative state rather than infer success solely from transport delivery.

## Scaling behavior

Gateway replicas independently consume the canonical Redis channel and deliver only to their local sockets. Sticky sessions are not required for correctness.

Room/user recipient indexes are partitioned across fixed in-process shards. Per-pod and per-user connection budgets remain explicit. Scale using measured connection count, memory, CPU, network egress, reconnect pressure, queue/backpressure, and Redis load.

## Autoscaling and observability

Prometheus metrics include active/accepted connections, auth denials, capacity denials, slow-client closes, valid/invalid/duplicate events, best-effort drops, lower-priority evictions, dedupe size, and Redis subscription health.

Structured logs avoid tokens. OpenTelemetry spans cover connection, subscription, command, and Redis fanout paths.

## Local development

Start FastAPI, Redis/Valkey, and the Go gateway. Configure:

- `REALTIME_AUTH_VERIFY_URL`
- optional `REALTIME_COMMAND_URL` (defaults next to the verify endpoint)
- `REALTIME_REDIS_URL`
- `REALTIME_ORIGINS` where required

Flutter points `VM_REALTIME_WS_URL` at the Go gateway. Mediasoup configuration remains separate.

## Testing

Required gateway checks:

- `gofmt` clean tree;
- `go vet ./...`;
- `go test ./...`;
- `go test -race ./...`.

Repository CI also validates backend contracts, Flutter tests/analyze/build, media services, infrastructure, container builds, and architecture guards forbidding new feature-owned application WebSockets.

## Deployment notes

Expose `/ws` through a WebSocket-capable load balancer with long idle timeouts. Use `/ready` for readiness and `/live` for liveness. Drain before scale-in and allow enough healthy replicas for reconnect surge.

Do not route mediasoup signaling through this gateway.

## Change checklist

Before changing this contract, verify:

- FastAPI verify/command parity;
- room replay and snapshot fallback;
- user/users/staff/all routing isolation;
- queue priority/backpressure;
- presence and room lease compatibility;
- reconnect and drain behavior;
- browser subprotocol/token redaction;
- Go race/vet/tests;
- Flutter single-socket architecture guard;
- backend/media/infrastructure CI.

## Migration status

**Chunk 21 cutover implemented.**

Flutter `AppRealtimeHub` targets the Go `/ws` endpoint. Inbox and room application traffic use the shared socket. The legacy FastAPI Inbox and room application WebSocket routes are retired/unmounted and protected by architecture tests. Feature-created application sockets have been removed. Mediasoup/WebRTC signaling remains intentionally separate.
