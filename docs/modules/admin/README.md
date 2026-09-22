# Administration

## Purpose

Owns privileged control surfaces, role changes, support workflows, and audit visibility.

## Responsibilities

The module owns admin_logs, user_roles, special_permissions and domain-specific admin records. Routes should validate input and delegate business decisions to services.

## What this module owns

admin_logs, user_roles, special_permissions and domain-specific admin records.

## What this module does NOT own

This module does not own SFU transport state, edge routing, or client UI state.

## Source of truth

PostgreSQL is the durable source of truth for admin_logs, user_roles, special_permissions.

## Important files

`backend/app/api/routes/admin.py`, `backend/app/api/routes/control_center.py`, `backend/app/services/role_service.py`.

## Public API/contracts

admin and control-center routes under /api/v1. Preserve deployed request and response shapes while migrating implementation.

## Events published

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database tables and state: `admin_logs, user_roles, special_permissions`.

## Redis keys/state owned

No authoritative admin role or permission in Redis.

## Dependencies

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services.

## Security considerations

Every privileged write needs role and permission checks plus audit logging. Never log tokens, OTPs, or payment secrets.

## Failure modes

If audit persistence fails, high-impact changes should fail rather than be silently unaudited.

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

Existing FastAPI domain; no Go migration started.
