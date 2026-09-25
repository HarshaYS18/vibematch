# Room Control Service — Chunk 26

**Logical owner:** Room Control  
**Deployable:** `funkey-room-control`  
**Port:** 8085  
**Durable authority:** PostgreSQL using service-local credentials  
**Transport:** Go realtime gateway + realtime Redis/Valkey  
**Media:** canonical mediasoup service

## Purpose

Chunk 26 physically separates room correctness from the core API. Room Control owns durable room configuration, membership/admin state, kickouts, seats and seat applications, member requests, room chat persistence, room event/version state, activities, Watch Party durable state, Room Cricket tournament/match/ball state, room themes/reviews/inventory, and room moderation commands.

The extraction does not create a second room source of truth. PostgreSQL remains authoritative; Redis remains ephemeral/rebuildable and the Go gateway remains transport.

## Public routing

The existing client contract remains `/api/v1/rooms/**`. Core registers exact cross-domain routes first and then a compatibility catch-all proxy to Room Control. This preserves Flutter/API compatibility while avoiding direct core room writes.

Routes intentionally retained in core include:

- paid room-theme purchase, because the debit belongs to economy authority;
- room contribution ranking, because it is an economy/profile projection;
- room levels and room media routes, because they belong to their existing domains. Room Cricket public routes are compatibility facades that proxy into Room Control.

The catch-all proxy is registered after those exact routes so it cannot shadow them.

## Database authority

`deploy/postgres/room-control-ownership.sql` transfers these tables to `funkey_room_control_owner` and grants DML to `funkey_room_control_runtime`:

`rooms`, `room_participants`, `room_seat_states`, `room_realtime_events`, `room_member_requests`, `room_seat_applications`, `room_chat_messages`, `room_kickouts`, `room_themes`, `user_room_theme_inventory`, `room_theme_reviews`, `cricket_tournaments`, `cricket_matches`, and `cricket_ball_events`.

Identity/profile/economy tables are read-only compatibility dependencies. Room Control never writes wallets, identity last-seen state, or connected-liveness presence. Online presence is the Go realtime Redis lease projection; the legacy `user_room_presence` table has no Room Control runtime write grant.

## Background transaction safety

FastAPI dependency overrides do not affect direct `SessionLocal()` calls. Therefore all isolated room command/snapshot transactions use `room_db_context.room_session()`. The Room Control process configures that factory to its service-local SQLAlchemy session at startup. Core fallback exists only for compatibility/local execution.

## Cross-domain theme purchase

Paid theme purchase is an orchestrated saga-like synchronous flow:

1. core authenticates the user and obtains a theme quote from Room Control;
2. core calls Economy with a stable `room-theme-purchase:{user}:{theme}` business reference;
3. Economy performs the idempotent debit under Economy authority;
4. core asks Room Control to grant the theme inventory idempotently;
5. if step 4 fails, a retry reuses the same Economy mutation identity and retries the Room Control grant safely.

This preserves single ownership: economy owns money, Room Control owns room inventory.

## Failure semantics

If Room Control is unavailable, core returns a bounded 503 for proxied room authority routes. It must not fall back to direct core writes. Durable mutations that committed remain valid even if post-commit realtime fanout fails; clients recover through the authoritative snapshot protocol.

## Scaling and observability

Room Control exports the shared HTTP/database telemetry and `/metrics`, uses its own bounded PostgreSQL pool, has a 3-pod HA floor, topology spreading, PDB, and HPA up to 20 replicas. Its connection budget is included in Terraform and production configuration validation.


## Realtime and media authorization boundary

Chunk 26 completion removes the last core shared-database dependency on room
authority. Realtime capability issuance, subscription verification and
`/realtime/command` now call the authenticated Room Control internal API.
Ordinary room media authorization uses the same authoritative decision for
membership, kickout, seat, mic and room-version state. Call-room media remains
with the separate call authority.

If Room Control is unavailable these checks fail closed; core must not fall back
to querying `rooms`, `room_participants` or `room_seat_states` directly.
