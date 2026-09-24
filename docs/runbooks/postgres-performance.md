# PostgreSQL performance runbook

## Query-budget alert

When `funkey_http_db_query_budget_exceeded_total` increases:

1. identify the route template and service;
2. compare current query count with `backend/app/core/query_budget.py`;
3. inspect traces and slow-query fingerprints;
4. reproduce with the route's test fixture;
5. run `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` on the exact query shape;
6. fix N+1/query shape before raising a budget.

Never raise a query budget merely to make CI green.

## Slow queries and locks

Use `pg_stat_statements`, lock metrics, long-running transaction metrics and trace correlation. Do not log SQL parameters or message/content bodies.

## Index changes

Add an index only when a representative plan demonstrates its need. Record the target query, row cardinality and before/after plan in the change. Re-check write amplification and index size after rollout.

## Read replicas

Do not enable a replica route unless `contracts/database/storage-policy.json` is updated with a stale-tolerant route and operational lag/fallback rules. If replica lag violates its SLO, route approved reads back to primary.

## Partitioning

Do not partition based on projected user count alone. Collect table/index size, write rate, vacuum/autovacuum pressure, retention and plan evidence first.

## Incident fallback

PostgreSQL remains correctness authority. Redis/search/recommendation/read-replica degradation must fall back to authoritative primary reads or a bounded unavailable response; never manufacture business state from stale cache data.
