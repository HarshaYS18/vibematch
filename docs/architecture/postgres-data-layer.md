# PostgreSQL and data-layer hardening — Chunk 25

## Existing foundation

Chunk 25 builds on, rather than duplicates, the earlier database platform: PostgreSQL remains durable business authority; PgBouncer uses transaction pooling; application pools and timeouts are bounded; migrations connect directly; `pg_stat_statements`, lock/deadlock/long-transaction metrics, query counting and slow-query fingerprints are already present.

## Route query budgets

Hot reads have explicit query ceilings in `backend/app/core/query_budget.py`. A budget is a regression ceiling, not a latency SLO.

Production never fails a correct request only because instrumentation reports a budget breach. Instead it emits `funkey_http_db_query_budget_exceeded_total`, a structured warning and trace attributes. CI owns the hard enforcement.

Current protected routes are Vibes global/friends/saved feeds and Inbox conversation/message history.

## Inbox page batching

Conversation-list serialization must not execute message-window/read-receipt queries once per conversation. The page read batches participants, per-conversation bounded message windows with `row_number()`, and read receipts across the whole page.

## Index evidence

Migration `20260924_0200` adds only indexes that map to hot cursor queries:

- live Vibes feed: partial `(created_at DESC, id DESC)` for non-deleted posts;
- saved Vibes feed: the real join/order shape is plan-tested and reuses the existing selective `vibe_saves.user_id` index rather than adding a redundant save-time index;
- Inbox history: `(conversation_id, created_at DESC, id DESC)`.

CI seeds PostgreSQL and runs `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`; the test fails unless PostgreSQL uses the intended hot-path indexes. The saved-feed fixture uses many users so the user predicate has realistic selectivity and mirrors the actual service query shape.

## Read replicas

Read replicas are deliberately disabled. They may be introduced only after measured primary read pressure and only for explicitly stale-tolerant routes. Read-after-write, authorization, money, moderation/enforcement, room authority, Inbox mutation context and other correctness-sensitive reads stay on primary.

## Partitioning

No table is partitioned in Chunk 25. Partitioning requires measured table/index size or vacuum pressure, a stable partition key/retention model, demonstrated pruning benefit, and a migration/rollback runbook.

## Redis/cache correctness

Redis remains cache/projection/ephemeral state only. Business projection keys require TTLs and versioned payloads; Redis loss must never corrupt PostgreSQL truth.

## Rollback

The new indexes are additive. Query-budget telemetry can be disabled operationally by reverting application code without schema rollback. If an index creates unacceptable write amplification, revert the application first and remove only the specific index through Alembic after plan evidence is captured.
