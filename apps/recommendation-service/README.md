# Recommendation Service

Chunk 39 implements a disposable recommendation projection:

```text
Kafka retained events
  -> feature/signal extraction
  -> deterministic scoring
  -> Redis feed projection
  -> Recommendation API
```

Recommendation output is **never content or authorization authority**. Missing
or stale recommendations may degrade personalization only. Redis state is
reconstructable from retained Kafka events.

Consumer offsets are committed only after the projection update attempt, and
the service uses a dedicated consumer group. Candidate/member IDs are stable
domain identifiers; the service does not copy durable domain rows.
