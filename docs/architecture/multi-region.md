# Multi-region / global scale architecture

Chunk 40 regionalizes stateless APIs, realtime gateways, Redis roles, workers,
Search/Recommendation projections and media nodes. A global edge sends clients
to the nearest healthy region.

## Safety boundary

Economy remains **single-writer**. PostgreSQL remains one writable authority
unless a later, measured and explicitly approved database topology proves a
different model. Do not casually introduce active-active wallet/gift/purchase
writes.

```text
Global edge
  -> nearest healthy region
      -> API / GraphQL / Search / Recommendation
      -> regional realtime + Redis
      -> regional workers + media
      -> durable owner services
```

The serving region is observable through `X-FunKey-Region`. That header is
diagnostic only and is never trusted for authorization.

Regional projection systems may rebuild independently. Cross-region failover is
allowed only when the destination region has confirmed dependency readiness and
the authoritative database failover state is known.

The repository stays provider-neutral. CockroachDB, YugabyteDB, Spanner or a
multi-primary PostgreSQL substitute are **not** introduced merely to satisfy a
multi-region label; they require measured justification and a separate authority
decision.
