# ADR-015: Redis role isolation and ephemeral-state policy

**Status:** Accepted  
**Date:** 2026-09-23

## Context

A single Redis endpoint currently carries unrelated cache/rate-limit, realtime transport, and media-registry pressure. That couples failure domains and makes memory/eviction policy impossible to tune safely.

## Decision

Use three independent Redis/Valkey roles: application cache/rate-limit, realtime/presence/routing, and dedicated media registry. Each has its own endpoint, client pool, key namespace, memory policy, TTL expectations, metrics, and failover behavior.

All Redis roles remain CACHE or EPHEMERAL state. PostgreSQL/business services retain durable authority.

Current clients are single-endpoint clients and Redis Cluster is not claimed as supported. Media registry remains explicitly single-primary because of its Lua/multi-key design.

## Consequences

Cache eviction cannot directly consume realtime/media capacity. Realtime failure can be recovered by reconnect/snapshot reconciliation. Media registry failure returns temporary unavailability rather than inventing local routing truth.

Production operations must provision and monitor three HA endpoints and keep role URLs in secrets.
