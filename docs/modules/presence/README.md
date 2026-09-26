# Presence

## Purpose

Expose privacy-filtered connected-liveness and current-room projections without creating a second room-membership authority.

## Responsibilities

Connected liveness is an **ephemeral realtime projection**. The authenticated Go realtime gateway is the only writer of online/socket presence and refreshes TTL-scored Redis/Valkey leases. FastAPI presence routes are read-only compatibility surfaces over that projection.

Durable room membership, admin state and seats belong to Room Control in PostgreSQL and are intentionally separate from connected liveness.

## What this module owns

The presence domain owns no durable PostgreSQL business authority. It owns the contract for projecting global online state, user-to-room live leases, room-to-user live leases, and privacy-filtered public presence responses.

## What this module does NOT own

Presence does not own `room_participants`, room seats, room permissions, SFU transport state, identity `last_seen_at`, or client UI state. The legacy `user_room_presence` table is non-authoritative and receives no production runtime write grant.

## Source of truth

Connected online truth is the Go realtime gateway's Redis/Valkey lease set:

- `funkey:realtime:gateway:user-active:{user_id}`
- `funkey:realtime:gateway:user-rooms:{user_id}`
- `funkey:realtime:gateway:room-users:{room_public_id}`

Room membership truth remains PostgreSQL under Room Control. Redis loss must never be repaired by reviving database-heartbeat authority; presence reads fail closed/offline until leases rebuild from authenticated sockets.

## Important files

- `apps/realtime-gateway/internal/gateway/server.go`
- `backend/app/services/presence_projection_service.py`
- `backend/app/api/routes/presence.py`
- `backend/app/services/rooms/room_service.py`
- `frontend/vibematch_app/lib/app/app_shell.dart`
- `frontend/vibematch_app/lib/features/rooms/presentation/live_room_presence_shell_page.dart`

## Public API/contracts

Public/batch presence reads preserve deployed response shapes. Legacy `/presence/heartbeat` and room enter/leave compatibility routes are read-only/deprecated. Room REST heartbeat is retired; the canonical socket lease supplies steady-state liveness.

## Events published / consumed

No durable broker event is required to keep a connected user online. Socket connect/join/refresh/leave updates the bounded Redis leases directly. Durable room events remain Room Control events and must not be inferred from presence leases.

## Database tables/state owned

None for connected liveness. `user_room_presence` is legacy compatibility schema only and is not a writable production authority.

## Redis keys/state owned

Realtime gateway presence leases are ephemeral, TTL-bounded and rebuildable from active authenticated sockets plus durable room membership.

## Security considerations

Secret-room identity/location must not leak through public presence projection. Realtime leases are keyed by internal user IDs; public responses apply room/privacy visibility before exposing room metadata.

## Failure modes

If realtime Redis is unavailable, presence renders users offline/unknown rather than falling back to stale PostgreSQL heartbeat timestamps. Durable membership remains intact and reconnect rebuilds ephemeral leases.

## Retry/idempotency behavior

Socket lease refreshes are naturally idempotent ZSET updates. Presence reads may retry with bounded timeouts. No client timer should perform database presence writes.

## Scaling behavior

Presence scales with the Go gateway and dedicated realtime Redis role. FastAPI presence projection performs bounded Redis pipelines and bounded PostgreSQL metadata reads only for users/rooms that are actually leased.

## Observability

Track active socket leases, room lease counts, lease refresh failures, Redis latency/error rate, reconnect rate, and privacy-filter rejection counts without user PII in metric labels.

## Testing

Regression coverage must prove that Flutter does not run periodic REST/database heartbeats, FastAPI does not write `UserRoomPresence`, and the Go gateway maintains both global and room lease indexes.

## Deployment notes

Apply Redis topology/HA configuration and Room Control ownership SQL with the legacy `user_room_presence` write revocation. Do not grant any production runtime a compatibility DB heartbeat writer role.

## Known migration status

Post-Chunk-32 repair completed the one-Go-socket presence cutover: Flutter/REST/PostgreSQL heartbeat authority is retired and Go realtime is the sole connected-liveness writer.
