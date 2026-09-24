# Architecture Authority Registry

**Owner:** Platform Architecture  
**Status:** canonical human guide synchronized through Chunk 32 repair  
**Machine contract:** `contracts/architecture/authorities.yaml`  
**Guard:** `scripts/check_backend_architecture.py`

## Purpose

For every important mutable state, the machine registry records classification,
logical owner, current deployable/storage, permitted mutators, rebuild source,
migration status and change contract. The machine registry is the enforceable
source; this file explains the current domain map.

## Classification rules

- **AUTHORITY** — one durable business owner and one mutation boundary.
- **PROJECTION** — derived from named source states and rebuildable.
- **CACHE** — disposable acceleration only.
- **EPHEMERAL** — reconstructable runtime state such as presence/replay leases.

Transport, Flutter, Redis, Kafka, OpenSearch, ClickHouse, observability and
GraphQL never become durable business authorities merely because they store a
copy or route traffic.

## Current domain map

| Capability | Logical owner | Current deployable | Rule |
|---|---|---|---|
| Identity/accounts/sessions | Identity | `identity-service` | Tokens/capabilities are credentials, not user authority. |
| Profile/social/family membership | Profile/Social | `profile-social-service` | Composite profile reads may remain read-only elsewhere. |
| Rooms/membership/permissions/seats/Watch Party/activity | Room Control | `room-control-service` | Go transports deltas; PostgreSQL owner state wins. |
| Online presence/routing/replay | Realtime | Go gateway + realtime Redis | EPHEMERAL/rebuildable only. |
| Inbox + family community chat | Inbox | `inbox-service` | Durable messages/read state are Inbox-owned. |
| Vibes | Vibes | `vibes-service` | Feed/search/ranking copies are projections. |
| Wallet/supply/gift/game settlement/mission rewards | Economy | `economy-service` | Exclusive financial writer; balanced journal is audit evidence. |
| VIP/SVIP materialization | Economy-derived projection | `economy-service` + readers | Rebuildable from Economy value history; not profile authority. |
| Game catalog/session/round/bet/risk/stats | Game Platform | `game-platform-service` | Never mutates wallet/financial tables. |
| Notifications + push delivery state | Notification | `notification-service` | FCM/provider is transport only. |
| Media upload/processing metadata | Media Control | core control + media workers | PostgreSQL is control-plane authority; object storage is bytes only. |
| Search | Search Projection | direct DB search today | Future OpenSearch remains rebuildable. |
| Analytics | Analytics Projection | not deployed | Future Kafka/ClickHouse copies are downstream only. |
| Recommendations | Recommendation Projection | not deployed | Ranking output is rebuildable. |
| Flutter room/display cache | Flutter client cache | Flutter | Backend snapshot/delta wins durable conflicts. |

## Important resolved boundaries

### Games vs Economy
Game Platform owns gameplay lifecycle. Economy owns every value movement,
including wager debit and final settlement. Physical co-location or a compatibility
facade never grants Game Platform financial authority.

### Missions
Mission progress is a projection. Reward claims become durable only through the
Economy ledger/transaction boundary.

### Presence
Socket liveness is a Redis/Valkey lease and replay is bounded ephemeral state.
Room membership remains Room Control PostgreSQL authority.

### Media
Media v2 upload sessions, processing status and variants are durable control-plane
state. Object storage/CDN owns bytes, while `backend_media` owns WebRTC transport.

## App source registry relationship

`/api/v1/app/source-of-truth/master` and Flutter `AppSourceRegistry` describe
screen read/write/realtime contracts. They do not compete with this registry.

## Change and rollback rule

An ownership move must update the machine registry, architecture docs, DB roles,
tests/guards and runbook in the same migration. Do not mark a cutover complete
while the old writer still has mutation rights.

Rollback must preserve exactly one durable writer. Never recover by enabling
dual writes.

## Known future projections

OpenSearch, Kafka/ClickHouse, Recommendation Platform and GraphQL read BFF are
not deployed business authorities. Their future introduction must preserve the
current owner graph.
