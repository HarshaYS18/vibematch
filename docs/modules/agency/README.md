# Agency

## Purpose

Documents agency and family-facing business boundaries that currently span existing services.

## Responsibilities

The module owns family membership and related economy statistics where implemented. Routes should validate input and delegate business decisions to services.

## What this module owns

family membership and related economy statistics where implemented.

## What this module does NOT own

This module does not own SFU transport state, edge routing, or client UI state.

## Source of truth

PostgreSQL is the durable source of truth for family_economy_stats, family_member_stats; inspect migrations before adding agency tables.

## Important files

`backend/app/api/routes/families.py`, `backend/app/api/routes/families_economy.py`, `backend/app/models/economy_stats.py`.

## Public API/contracts

family routes under /api/v1; dedicated agency contract is not yet defined. Preserve deployed request and response shapes while migrating implementation.

## Events published

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database tables and state: `family_economy_stats, family_member_stats; inspect migrations before adding agency tables`.

## Redis keys/state owned

No agency-specific Redis authority.

## Dependencies

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services.

## Security considerations

Agency privileges and payouts must use explicit roles and ledger records. Never log tokens, OTPs, or payment secrets.

## Failure modes

Do not infer entitlement from client labels; fail closed on missing contract.

## Retry/idempotency behavior

Reads and writes should use bounded timeouts. Retries are safe only for read operations or writes backed by an idempotency key and known commit outcome.

## Scaling behavior

Scale stateless API replicas only within the PostgreSQL connection budget.

## Autoscaling metrics

Track route request rate, p95 latency, error rate, transaction latency, DB pool use, and domain-specific rejection counts. Trace commands through commit and fanout with a request ID; avoid user PII in metric labels.

## Observability

Trace commands through commit and fanout with a request ID; avoid user PII in metric labels.

## Local development

Start dependencies with `.\\scripts\\dev-up.ps1`, then run affected backend tests with `python -m unittest discover -s backend/tests -p test_*.py` from the repository root with the backend import path configured, or use the test command in the root README.

## Testing

Add a regression test for authorization, transaction outcome, and duplicate/reconnect behavior when relevant.

## Deployment notes

Apply Alembic first; roll out compatible API behavior; check readiness and error metrics.

## Change checklist

Before changing this module: identify the owning table and contract, add an additive migration if needed, preserve Flutter compatibility, verify permission checks, and document rollback.

## Known migration status

Dedicated agency module has not started; current behavior is in FastAPI family routes.
