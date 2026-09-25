# Recommendation platform architecture

```text
Kafka retained events
  -> signal/feature computation
  -> candidate scoring
  -> Redis feed projection
  -> Recommendation API
```

The initial ranker is deliberately deterministic and explainable: weighted user
signals receive a six-hour half-life plus a tiny stable tie-breaker. Later ML
rankers may replace the score function behind the same authority boundary.

## Invariants

- Kafka is input history; it is not synchronous RPC.
- Redis is reconstructable projection/cache state.
- Recommendation IDs point to authoritative domain objects.
- blocked candidates are removed immediately from the user projection.
- consumer offsets are manual and committed after projection handling.
- the service cannot mutate domain content or Economy state.
- experiments/ML models must remain versioned and rollbackable.
