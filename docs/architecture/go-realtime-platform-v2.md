# Go Realtime Platform v2

**Owner:** Realtime Platform  
**Status:** Chunk 21 implemented  
**Application transport:** one Go WebSocket  
**Media signaling:** separate mediasoup Socket.IO/WebSocket path

## Goal

Every authenticated FunKey client owns one application WebSocket through the Go realtime gateway for:

- Inbox events and presence hints
- room deltas and room replay/resume
- notifications
- wallet/economy/gift updates
- profile/social/global events
- session invalidation and control events

The mediasoup signaling channel remains separate because it is media-plane protocol traffic, not application realtime.

## Authority boundary

The Go gateway owns transport only:

- connection lifecycle
- authentication/re-authentication
- authorized room subscriptions
- fanout indexes
- bounded backpressure
- transport replay
- connection/presence leases
- drain and transport metrics

It never becomes authority for identity, moderation, room membership, seats, messages, wallet value, gifts, notifications, or media state. Durable writes remain in the owning FastAPI/domain service.

## Event scopes

The canonical backend event channel is `funkey:realtime:events`.

Supported scopes:

- `user` — one user on all connected devices
- `users` — an explicit bounded set of user IDs
- `room` — only clients with an authorized room subscription
- `staff` — authenticated staff connections only
- `all` — every authenticated application connection

Every event has a stable `event_id`, version, payload, and optional transport metadata. Unknown payload fields are opaque to the gateway.

## Priorities and backpressure

Outbound delivery uses one bounded per-client queue with three logical priorities:

1. **critical** — session/security/control/resync/revocation events;
2. **normal** — durable-domain state changes, room deltas, Inbox messages, wallet/gift/notification updates;
3. **best_effort** — typing/activity/presence hints and similar lossy UI affordances.

When a queue is full:
- best-effort events may be dropped;
- critical events may evict lower-priority queued items;
- a client that cannot accept required normal/critical traffic is closed and must reconnect/resync.

No unbounded queue is allowed.

## Hub sharding

High-frequency room/user recipient indexes are partitioned across fixed in-process shards. Connection admission/drain remains globally coordinated, but room/user fanout does not require one process-wide routing mutex.

Event deduplication is bounded in both TTL and entry count.

## Room recovery

Chunk 20's room transport stream is consumed directly by the Go gateway:

```text
subscribe room + optional stream/last_sequence
  -> authorize through FastAPI
  -> register room subscription
  -> if same live stream and replay is contiguous: replay
  -> otherwise: subscribed ack with resync_required=true
  -> Flutter fetches authoritative RoomSessionRepository snapshot
```

Redis replay remains ephemeral. PostgreSQL room version/event sequence remain durable authority.

## Authentication

FastAPI/Identity remains the authorization issuer, but connection/subscription verification is no longer a periodic HTTP hot path.

Before opening the application socket, Flutter requests a short-lived Ed25519 connect capability from `POST /api/v1/realtime/capability`. The capability contains server-derived identity/session/device claims and the `realtime:connect` scope. For a room subscription, Flutter requests a separate room-bound capability after the authoritative room join; that grant contains `room:subscribe`, the exact room ID, server-derived permission hints, and the current durable room realtime version as the membership-version binding.

Go fetches only the public Ed25519 key from `GET /api/v1/realtime/capability-key`, caches it, and verifies signature, issuer, audience, token version, expiry, scope, and room binding locally. The gateway never trusts client-supplied user/staff identity.

Browser-compatible clients authenticate through the WebSocket subprotocol list:
- `funkey.v2`
- `bearer.<access-token>`
- `capability.<connect-capability>`

The server selects only `funkey.v2`; credential-bearing subprotocol values are never echoed and must be redacted by edge logs. The access token remains available only for allowlisted command relay back to authoritative FastAPI.

Room subscribe commands include their own short-lived `capability`. There is no periodic Go-to-FastAPI reauthorization timer. Immediate invalidation is event-driven through critical `auth.session_revoked` and `room.permission_revoked` events; missed revocations are bounded by capability expiry and the next authoritative mint.

`POST /api/v1/realtime/verify` is retained temporarily as a rollback/control-plane seam, not the normal connect/subscribe path.

## Migration sequence

FastAPI feature WebSockets are removed only after:

1. **expand** — Go supports all required scopes/contracts;
2. **mirror/shadow** — existing FastAPI publishers also publish equivalent Go-gateway events;
3. **compare** — tests/metrics prove envelope/recipient parity;
4. **canary/ramp** — Flutter `AppRealtimeHub` connects to Go while legacy consumers remain available;
5. **freeze old writes** — no new feature may add a FastAPI application WebSocket;
6. **soak** — observe reconnects, gaps, slow clients, drops, event parity;
7. **delete/guard** — remove legacy Inbox/room/feature application sockets and add CI guards.

Do not delete mediasoup signaling.

## Flutter rule

`AppRealtimeHub` owns the one physical application socket. Feature code subscribes to typed/event-filtered streams from the hub or repositories. Feature code must not instantiate its own application WebSocket client.

`RoomSessionRepository` remains canonical room state authority; realtime events are inputs to it, not a second room store.

## Completion gates

Chunk 21 requires:
- multi-scope Go routing;
- staff-safe routing;
- bounded priority queue and bounded dedupe;
- Go room replay/resume;
- mirrored Inbox/application events on the canonical Redis channel;
- Flutter `AppRealtimeHub` on Go `/ws`;
- room subscription/reconnect support;
- feature adapters consuming hub events;
- legacy FastAPI application sockets disabled/removed only after parity;
- architecture guard forbidding new feature application sockets;
- load/race/chaos/reconnect tests and all repository CI green.


## Implemented Chunk 21 checkpoint

The migration sequence above has been completed in the application codebase:

- the Go gateway exposes the single `funkey.v2` application socket;
- Flutter `AppRealtimeHub` owns the physical application connection;
- room subscriptions carry replay cursors and reconcile into `RoomSessionRepository`;
- Inbox, room membership, seat/settings/chat/activity/Watch Party, room-music control, and other application commands use the shared transport while FastAPI remains authoritative;
- backend events support `room`, `user`, `users`, `staff`, and `all` routing;
- bounded priority backpressure, bounded dedupe, capability authentication/revocation, leases, drain, and room replay are implemented;
- legacy FastAPI Inbox and room application WebSocket routes are retired/unmounted;
- feature-owned application WebSocket creation is blocked by CI architecture guards;
- mediasoup/WebRTC signaling remains separate by design.

This checkpoint does not make Redis or Go a durable domain authority. Snapshot recovery and FastAPI/PostgreSQL ownership remain mandatory invariants.


## Chunk 22 capability-auth checkpoint

Chunk 22 moves connection and room-subscription authorization from repeated HTTP verification to short-lived signed capabilities without moving authority into Go:

- FastAPI mints Ed25519 capabilities only after normal access-token/session/device/ban/policy checks;
- connect and room-subscribe scopes are separate, and room grants are bound to one room;
- Go verifies capabilities locally using only the API public key;
- the access token remains confined to authoritative command relay;
- session/device replacement and bans publish critical user revocations;
- kicks and membership removal revoke the affected room subscription;
- room privacy changes invalidate current room grants so clients must remint;
- Flutter remints connect capabilities on reconnect and room grants on expiry/revocation;
- the periodic HTTP reauthorization loop is removed;
- the old verify endpoint remains available only as a temporary rollback seam.

See `docs/adr/ADR-018-realtime-capability-authentication.md` for key ownership, rotation, and failure semantics.
