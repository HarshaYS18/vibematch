# Redis/Valkey outage

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Never paste credentials, URLs containing passwords, private content, or payment data into incident notes.

## Identify the failed role first

FunKey intentionally separates:
- application cache/rate-limit Redis;
- realtime/presence/routing Redis;
- media-registry Redis.

Do not treat them as interchangeable during mitigation.

## Symptoms

**Cache/rate-limit role:** API rate limiting can fail closed; cache hit rate drops.

**Realtime role:** socket leases, cross-instance fanout, gateway routing and distributed command dedupe degrade; clients may require snapshot resync.

**Media-registry role:** new media assignment/heartbeat/drain operations fail unavailable until registry health returns.

## Dashboards and metrics

Inspect Redis availability, primary/replica/failover state, used versus max memory, evictions, rejected connections, connected clients, command latency/ops, application realtime subscription health, and media-registry heartbeat failures.

## Immediate actions

1. Identify the exact role and endpoint.
2. Stop risky deploys or scale changes that increase pressure.
3. For realtime failure, expect reconnect/resync and preserve authoritative PostgreSQL state.
4. For media-registry failure, stop media node scale-in until assignments/heartbeats are healthy.
5. For cache/rate-limit failure, do not bypass abuse controls by silently failing open.

## Safe mitigation

Use the selected provider's tested HA failover path for that role. Restore connectivity and let TTL state rebuild naturally. Realtime clients refetch authoritative snapshots. Media nodes heartbeat and rooms re-resolve.

## Dangerous actions

Do not:
- copy media-registry traffic onto the cache/realtime Redis during an incident;
- enable Redis Cluster for current clients;
- remove memory ceilings;
- bulk-delete keys to clear pressure without understanding the affected role;
- reconstruct wallet, membership, message, moderation, or other durable truth from Redis.

## Recovery validation

Verify the affected exporter reports healthy, memory/connection pressure normalizes, realtime subscription health recovers, clients reconcile snapshots, media heartbeats/assignments recover, and API rate limiting resumes. Confirm no durable correctness invariant depended on the lost Redis keys.

## Escalation evidence

Collect role name, provider incident/failover timeline, memory/eviction/rejected-connection charts, command latency, application error window, and affected node/room counts without exposing user content or credentials.
