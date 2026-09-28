# Search / OpenSearch runbook

When search errors rise, first check Search readiness, OpenSearch cluster health,
NATS durable backlog and projection failures. Do not modify authoritative
PostgreSQL state to repair the index.

For projection lag, restore OpenSearch/consumer health and allow the durable NATS
consumer to drain. For mapping changes, create a new versioned index and replay/
backfill before alias cutover.

If OpenSearch is unavailable, search may degrade while normal commands and
realtime rooms continue. Rollback the Search client/proxy independently.

Production evidence must include index rebuild, one node failure, projection
redelivery/idempotency, query p95, and no silent projection loss.
