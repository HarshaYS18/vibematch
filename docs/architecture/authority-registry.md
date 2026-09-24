# Architecture Authority Registry

**Owner:** Platform Architecture  
**Status:** Canonical architecture contract introduced in Chunk 15  
**Machine contract:** `contracts/architecture/authorities.yaml`  
**Guard:** `scripts/check_backend_architecture.py`

## Purpose

For each important mutable state this registry answers: who owns it, where it lives today, where it may live after migration, who may mutate it, who may copy it, and how copies converge or rebuild.

The machine registry is enforceable. This document explains policy without duplicating every machine field.

## Logical owner versus current deployable

A logical owner is a business boundary. A current deployable is the process containing that boundary today. Chunk 15 does not pretend future microservices are deployed. Most domains still execute in `core-api`; later chunks extract them with expand/mirror/shadow/compare/canary/ramp/cutover.

See [state-classification.md](state-classification.md) for AUTHORITY, PROJECTION, CACHE, and EPHEMERAL semantics and [service-boundaries.md](service-boundaries.md) for extraction rules.

## Domain map

| Capability | Logical owner | Current runtime | Rule |
|---|---|---|---|
| Identity/session policy | Identity | core-api | Tokens are credentials, not a second user authority. |
| Profile/social/families | Profile/Social | core-api | Durable social facts remain PostgreSQL-backed until extraction. |
| Rooms/membership/permissions/seats/Watch Party/activities | Room Control | core-api | Go realtime transports deltas; it does not own durable room truth. |
| Online presence/routing | Realtime | compatibility paths + Go gateway | Target presence is Redis/Valkey lease state; membership remains Room Control. |
| Inbox | Inbox | core-api + compatibility WS | Messages are durable; typing is ephemeral. |
| Vibes | Vibes | core-api | Feed/index/ranking copies are projections. |
| Wallet/ledgers/gift/game settlement/mission rewards | Economy | economy-service + compatibility facades | No other domain independently mutates financial truth. |
| Game catalog/round lifecycle | Game Platform | game-platform-service + CDN bridge | Final value settlement is an Economy command. |
| Notifications | Notification | core-api/worker | FCM is delivery transport only. |
| Media metadata/objects | Media Control | core-api + storage | mediasoup owns transport lifecycle only. |
| Search | Search Projection | direct DB search today | OpenSearch is projection only. |
| Analytics | Analytics Projection | not deployed | Kafka/ClickHouse/data lake are downstream projections. |
| Recommendations | Recommendation Projection | not deployed | Ranker output is rebuildable. |
| Flutter | client cache authority only | Flutter | Backend snapshots/deltas win durable-state conflicts. |

## Audit findings fixed

**Games versus Economy:** historical Games docs claimed financial tables. Game Platform now owns catalog/round/risk lifecycle; Economy owns wallets, value pools/ledgers, and final settlement. Physical co-location does not grant ownership.

**Missions:** current progress is computed from room events and gift transactions, so it is a PROJECTION. Reward claims are durable through Economy-owned wallet ledger entries.

**Watch Party/activities:** these are implemented. Current canonical state is persisted in `room_realtime_events`; later current-state tables remain under Room Control.

**Presence:** Chunk 20 makes online room socket presence an EPHEMERAL Redis/Valkey lease. Periodic room DB heartbeat is no longer the normal liveness path. Join/leave and durable membership remain PostgreSQL-backed. Chunk 21 completes application-socket convergence.

## App source registry relationship

The existing `/api/v1/app/source-of-truth/master` and Flutter `AppSourceRegistry` describe screen read/write/realtime contracts. They are not competing architecture authorities.

## Change, migration, rollback, observability

Before mutating a state, identify its registry entry and owner. Ownership changes require architecture/migration review before code. Update projections only after authoritative success and publish through the approved transactional event path where applicable.

Chunk 15 has no production data migration; rollback is a Git revert. Later ownership moves use expand, mirror, shadow, compare, canary, ramp, freeze old writes, soak, remove old path, then strengthen the guard.

The registry itself has no runtime telemetry; CI conformance is its signal. Runtime observability is standardized in Chunk 16.

## Known gaps

Identity and Game Platform durable session registries are live; presence remains transitional; OpenSearch/Kafka/ClickHouse/Recommendation are explicitly not deployed; naming a logical owner does not mean physical service extraction is complete.
