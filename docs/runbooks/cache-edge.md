# Cache / edge runbook

For a cache incident, first verify the authoritative owner is healthy. Cache loss
should reduce performance, not correctness.

If hit rate collapses or a hot key stampedes, inspect namespace TTLs, Redis
latency, lock contention and origin load. Do not increase TTL for authorization,
wallet, sessions or private content because those domains are not cacheable
authority.

For bad/stale public cache data, bump/invalidate the versioned namespace and let
the projection refill from the owner. Purging cache must not require database
repairs.
