# Room Control service runbook

## Health

Check `/live`, then `/ready`. Readiness requires the Room Control PostgreSQL credential to reach the authoritative database. Inspect `/metrics`, PostgreSQL pool saturation, HTTP latency/error rate, and room command traces.

## Public 503s

A core response of `Room Control service unavailable` means the compatibility proxy could not reach the extracted authority. Verify the `funkey-room-control` Service/endpoints, pod readiness, network policy, service DNS, and `ROOM_CONTROL_SERVICE_URL`.

Do not temporarily restore direct core room writes. That creates competing authorities.

## Database permission errors

Confirm the production login is a member of `funkey_room_control_runtime` and that `deploy/postgres/room-control-ownership.sql` has been applied after Alembic. The core login should not inherit that runtime role.

If a room path unexpectedly requests cross-domain write permission, treat it as an architecture defect; do not broaden grants as a shortcut.

## Theme purchase recovery

A paid theme purchase may commit the economy debit before an inventory-grant request fails. Retrying the same theme purchase is safe: core serializes on the wallet row and detects the existing `ROOM_THEME_PURCHASE` ledger row; Room Control grants inventory idempotently.

Before manual intervention, check both the wallet ledger and `user_room_theme_inventory`. Never create a second debit to repair a missing grant.

## Room state/fanout failures

PostgreSQL state/version/event data remain authoritative. If a durable room command commits but realtime fanout fails, clients must recover through room snapshot/replay semantics. Follow `docs/runbooks/room-state-desync.md` for replay issues.

## Rollback

Roll back the Room Control/core images as a compatible pair while retaining the expanded schema and service ownership roles. Keep exactly one writer authority. Do not point both core direct room routers and Room Control at production write credentials simultaneously.


## Presence and Cricket repair boundaries

Connected room liveness is not recovered from PostgreSQL heartbeat timestamps. The Go realtime gateway owns TTL Redis leases; if those leases are unavailable, restore the realtime Redis/gateway path and allow sockets to rebuild them. Do not grant Room Control or core write access to `user_room_presence`.

Room Cricket is durable Room Control state. Public core Cricket routes proxy to Room Control; mutations require host/admin permission, reads require room view membership, scoring serializes on the match row, and ball events are stored in `cricket_ball_events`. Do not bypass Room Control with direct core DB writes during an incident.
