# Redis / Valkey Platform

**Owner:** Platform Architecture / Realtime  
**Status:** Chunk 19 platform contract

## Principle

Redis/Valkey is never durable business authority in FunKey. Losing every Redis role may reduce availability, presence accuracy, routing continuity, cache hit rate, and abuse-control continuity, but it must not destroy authoritative identity, membership, seats, messages, moderation history, wallet/ledger state, Vibes content, or business history.

The machine-readable contract is `contracts/redis/topology.json`.

## Role isolation

FunKey uses three independent logical Redis roles.

### Application cache / rate limit

Environment: `CACHE_REDIS_URL`

Owns only rebuildable cache entries and bounded rate-limit windows. Cache pressure must not consume realtime routing capacity.

Key prefixes:
- `funkey:cache:`
- `funkey:ratelimit:`

Production requires a memory ceiling. Target eviction policy is `allkeys-lfu`. Losing rate-limit keys temporarily weakens distributed throttling, so rate-limit service loss is fail-closed at the API middleware while durable application state remains untouched.

### Realtime / presence / routing

Environment: `REALTIME_REDIS_URL`

Owns socket leases, cross-instance room fanout, gateway node/client leases, short command dedupe, and other reconstructable online state.

Canonical prefix: `funkey:realtime:`

Production requires a memory ceiling and TTL discipline. Target eviction policy is `volatile-ttl`; keys that must survive without TTL do not belong here.

Redis Pub/Sub is delivery, not durability. After disconnect/failover, clients refetch the authoritative REST snapshot and rebuild leases.

### Media registry

Environment: `MEDIA_REGISTRY_REDIS_URL`

Owns media node heartbeats, draining flags, capacity reservations, and sticky room-to-node assignments.

Canonical prefix: `funkey:media:`

This role intentionally requires a dedicated HA **single-primary** Redis/Valkey service because the current Lua registry spans dynamic keys and is not Redis Cluster hash-slot safe. Target memory policy is `noeviction`; on saturation the registry fails requests instead of silently discarding routing state.

## Current Redis Cluster readiness

Current clients use single-endpoint Redis clients and are **not Redis Cluster clients**. Chunk 19 records this explicitly rather than pretending cluster support exists.

A future Cluster migration requires:
- cluster-aware Python and Go clients;
- hash-slot-safe multi-key operations/scripts;
- Pub/Sub semantics validated under the selected cluster mode;
- failover/reconnect tests;
- key-prefix and TTL contract tests;
- measured capacity evidence.

Media registry remains single-primary until ADR-008 is replaced after a compatible Lua/key redesign.

## TTL contract

The checked-in contract records:
- rate-limit window keys: 120 seconds;
- FastAPI socket lease score: 30 seconds;
- FastAPI socket lease key expiry: 90 seconds;
- Go realtime gateway leases: 60 seconds;
- command dedupe: 300 seconds;
- media node heartbeat: 30 seconds;
- media room assignment: 86,400 seconds.

TTL values are correctness/cleanup bounds for ephemeral state, not durable retention.

## Connection policy

Every process has bounded Redis connection pools and bounded connect/socket timeouts. Application cache, realtime, and media-registry clients are separate pools. Production must provide three distinct role endpoints.

## HA / failover

Each role needs a managed HA endpoint or equivalent primary/replica failover mechanism. Failover expectations differ:

- cache: misses rebuild;
- rate limiting: API fails closed while the role is unavailable;
- realtime: connected clients may lose distributed fanout/leases and must resync;
- media registry: assignment calls fail unavailable until the primary is healthy; clients re-resolve afterward.

Do not copy media registry keys into a general cache instance during an incident.

## Observability

Each role is scraped independently with redis_exporter/Valkey-compatible metrics. Track:
- exporter/Redis availability;
- used/max memory;
- evictions;
- rejected/failed connections;
- connected clients;
- command latency/ops;
- replication/failover state.

Application metrics continue to track realtime Redis subscription health and business-path errors.

## Production secrets

Redis URLs may contain credentials and therefore belong in Kubernetes Secrets or the external secret manager, never ConfigMaps. API receives all three role URLs; the Go gateway receives only `REALTIME_REDIS_URL`; monitoring uses dedicated read-only/monitoring credentials where the provider supports ACLs.

## Completion gate

Chunk 19 is complete when role separation is enforced in production validation, local development uses three Redis roles, media and realtime callers use the correct client, key/TTL contracts are tested, exporter manifests and alerts render, Redis-loss behavior is regression-tested, and existing backend/Go/media/Flutter/platform CI remains green.
