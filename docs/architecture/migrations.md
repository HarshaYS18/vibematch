# Schema and domain migration policy

Alembic in `backend/alembic/` is the only production schema mutation graph while FastAPI owns the schema. The checkpoint includes a frozen baseline, merge revisions, and schema-ownership takeover. Keep that history intact. Do not use `Base.metadata.create_all()`, runtime `ALTER TABLE`, or a second Go migration tool against the same database.

## Before release

1. Review the migration against a recent sanitized staging clone and verify a single Alembic head with `cd backend; alembic heads`.
2. Check lock duration, backfill size, index strategy, and whether old and new application versions can run at the same time. Use expand/migrate/contract for incompatible changes.
3. Take and verify a backup/PITR checkpoint. Record the database version and current Alembic revision.
4. Run the migration once as a controlled job before promoting API replicas. Confirm `alembic current` equals the expected head and start the API schema guard.
5. Smoke test auth, room join, wallet/ledger write and readback, inbox, media discovery, and gateway/worker contracts affected by the change.

## Domain migration to Go

Move a bounded domain only after its HTTP/event contract, schema owner, parity suite, shadow comparison, canary metrics, and rollback route are explicit. A Go service may read a domain while FastAPI remains its sole writer; two independent writers require a separate ownership transition plan. The gateway does not take room, seat, ban, or wallet authority merely by handling sockets.

## Failed migration

Stop deployment and use the [failed migration runbook](../runbooks/failed-migration.md). Prefer a reviewed forward fix for an applied additive revision. A database restore requires the [restore runbook](../runbooks/database-restore.md), ledger reconciliation, and a known recovery point. Never silently stamp a revision or delete applied migration files.
