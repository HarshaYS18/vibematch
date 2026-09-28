# Vibes Service Runbook

## Health

- `GET /live`: process liveness.
- `GET /ready`: PostgreSQL connectivity.
- Public requests remain under `/api/v1/vibes/**`.

## Primary signals

Watch request rate, p95/p99 latency, DB pool saturation/timeouts, query count for feed routes, 5xx rate, outbox age, worker retry/DLQ counts, and Vibes fanout internal-call failures.

## Degraded dependencies

- NATS/worker unavailable: Vibes writes remain durable; fanout/media projections lag in the outbox.
- Inbox unavailable: direct mention Inbox snapshots may be skipped; in-app Vibes notifications remain durable.
- Search/recommendation unavailable: chronological/following PostgreSQL feed remains available.
- Redis unavailable: Vibes durable content/feed remains correct.

## Counter incident

If a denormalized counter is suspected, compare it with the authoritative engagement tables before changing data. Repair with a controlled migration/maintenance job; do not add request-time aggregate counting back to `_post_response`.

## Cursor incident

Treat malformed cursors as HTTP 400. Verify `ix_vibe_posts_feed_cursor` and compare adjacent pages for duplicate/missing `(created_at,id)` pairs.

## Rollback

Roll back the Vibes deployment/ingress first. The additive Chunk 24 schema is compatible with the previous code. Keep the outbox and counters in place during rollback.
