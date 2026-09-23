# PostgreSQL Platform Foundation

**Owner:** Platform Architecture / Database  
**Status:** Chunk 18 platform contract

## Purpose

PostgreSQL remains FunKey's durable business-state authority. Chunk 18 adds the connection, pooling, observability, timeout, and future service-isolation foundation required before service extraction.

This chunk does not move business tables to new databases. Logical ownership remains defined by the Chunk 15 authority registry.

## Connection topology

Application traffic uses PgBouncer in **transaction pooling** mode where compatible:

```text
API / Worker / future internal services
  -> bounded SQLAlchemy client pools
  -> PgBouncer transaction pool
  -> PostgreSQL
```

Migrations, DBA work, restore tooling, and operations that require session semantics use a separate **direct PostgreSQL DSN**. They do not use transaction pooling.

The runtime setting `DB_POOLER_MODE=transaction` therefore requires `MIGRATION_DATABASE_URL` to be configured separately from `database_url`.

## Connection budgets

Two budgets are distinct and must never be conflated:

1. **client connection budget** — application connections to PgBouncer;
2. **server connection budget** — PgBouncer plus direct operational connections to PostgreSQL.

The checked-in planning envelope is:

- API client budget: 150
- Worker client budget: 60
- rollout/surge reserve: 20
- PgBouncer max clients: 400
- PostgreSQL server limit planning value: 160
- PgBouncer server cap: 120
- direct migration/admin/monitoring/failover reserve: 40

These are guardrails, not measured capacity claims. Production provider limits must be substituted before deployment and the inequality must remain true.

## SQLAlchemy pool policy

Each deployable keeps a small bounded client pool even behind PgBouncer so request concurrency is backpressured locally.

- no unbounded overflow;
- bounded checkout timeout;
- pre-ping enabled;
- LIFO reuse enabled to let idle backend/client connections age out;
- rollback-on-return semantics;
- explicit recycle window.

The Go realtime and media signaling tiers do not open PostgreSQL pools unless a later authority decision requires it.

## Transaction timeouts

Direct PostgreSQL connections set:

- `statement_timeout`;
- `lock_timeout`;
- `idle_in_transaction_session_timeout`;
- connect timeout;
- low-cardinality `application_name`.

Under transaction PgBouncer, PostgreSQL role/database defaults provide statement/lock/idle-transaction timeout enforcement. Arbitrary session `SET` state is not a correctness dependency.

## PgBouncer compatibility rules

Transaction pooling is suitable for normal SQLAlchemy request transactions. A code path that requires session-scoped advisory locks, temporary tables spanning transactions, LISTEN/NOTIFY session ownership, or other session-local behavior must either be redesigned or use a specifically approved direct/session-pooled connection.

Do not silently switch the entire application to session pooling to accommodate one incompatible feature.

## pg_stat_statements and database monitoring

Production PostgreSQL must have `pg_stat_statements` enabled by the provider/database administrator. Local PostgreSQL enables it automatically.

A dedicated read-only PostgreSQL exporter role supplies:

- connection usage;
- deadlock counters;
- lock counts;
- long-running transaction count;
- `pg_stat_statements` query-ID aggregates;
- database/storage/WAL metrics exposed by the standard exporter.

Query text export remains disabled. Application slow-query telemetry logs only a hash/fingerprint and operation class, never SQL parameters or private content.

## Future service credentials and schema ownership

Physical service extraction must not create unrestricted cross-service DB access.

Target pattern:

```text
funkey_identity  -> identity-owned schemas/tables
funkey_inbox     -> inbox-owned schemas/tables
funkey_economy   -> economy-owned schemas/tables
funkey_room      -> room-owned schemas/tables
...
```

Each service receives a distinct login role. The role owns only its service schema/tables and gets explicitly granted read access to temporary compatibility surfaces during migration. Cross-service writes are forbidden after cutover.

The current modular monolith still uses the canonical schema/migration graph; Chunk 18 prepares policy and infrastructure but does not fake completed database splits.

## Migration path

For each later service extraction:

1. create the service login/schema boundary;
2. apply additive schema changes with the canonical migration process;
3. grant only required compatibility access;
4. mirror/shadow/compare;
5. cut application writes to the new logical/physical owner;
6. revoke obsolete cross-domain grants after soak;
7. audit privileges and table owners.

## Failure behavior

PgBouncer saturation applies backpressure; it must not trigger unbounded application retries. Database ambiguity on value-changing writes is reconciled through idempotency/ledger state rather than blind replay.

Loss of PostgreSQL remains a durable-state outage. Loss of the pooler is an availability incident, not a reason to bypass connection budgets with ad-hoc direct DSNs.

## Validation

Chunk 18 validation covers:

- client/server budget arithmetic;
- direct migration DSN requirement under transaction pooling;
- PgBouncer configuration rendered by Kubernetes/Compose;
- PostgreSQL exporter and Prometheus alerts;
- local `pg_stat_statements` bootstrap;
- slow-query telemetry without raw SQL;
- fresh/legacy Alembic replay;
- existing backend, media, Go, Flutter, and infrastructure CI.
