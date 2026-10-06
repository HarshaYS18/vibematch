# Redis / Valkey platform monitoring

Chunk 19 expects three independent HA Redis/Valkey endpoints supplied by the environment:

- application cache/rate-limit — `CACHE_REDIS_URL`
- realtime/presence/routing — `REALTIME_REDIS_URL`
- media registry — `MEDIA_REGISTRY_REDIS_URL`

The application URLs belong in workload secrets. Exporters use a separate `funkey-redis-monitoring` Secret with `cache_url`, `realtime_url`, and `media_registry_url`. Prefer provider ACLs/read-only monitoring users where supported.

These manifests deploy metrics exporters only; they do not pretend the repository provisions production Redis HA. The selected provider must configure primary/replica failover, memory ceilings, TLS/private networking, alerts, and the role-specific eviction policy from `contracts/redis/topology.json`.

Current application clients are single-endpoint clients. Point them at a managed failover endpoint, not individual replica addresses. Redis Cluster is not currently supported and must not be enabled without the redesign/tests described in the architecture guide.
