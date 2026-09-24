# Authentication

## Purpose

Authenticates users, records login history, and issues the existing JWT contract.

## Responsibilities

The module owns users and auth_identities; login_history. Routes should validate input and delegate business decisions to services.

## What this module owns

users and auth_identities; login_history.

## What this module does NOT own

This module does not own SFU transport state, edge routing, or client UI state.

## Source of truth

PostgreSQL is the durable source of truth for users, auth_identities, login_history.

## Important files

`backend/app/api/routes/auth.py`, `backend/app/services/identity_service.py`, `backend/app/core/security.py`.

## Public API/contracts

/api/v1/auth routes. Preserve deployed request and response shapes while migrating implementation.

## Events published

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database tables and state: `users, auth_identities, login_history`.

## Redis keys/state owned

No authoritative Redis state today; future rate-limit/session metadata only.

## Dependencies

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services.

## Security considerations

Token signing, Google OAuth client validation, device bans, and dev-login gating are security-critical. Never log tokens, OTPs, or payment secrets.

## Failure modes

Invalid signing configuration, OAuth outage, or ban-check failure must deny protected actions.

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


## Chunk 27 deployed boundary
Public /api/v1/auth traffic now reaches apps/identity-service through the stable core facade. Identity owns account/authentication mutation plus durable identity_sessions and identity_devices. New access tokens contain a session id and support durable revocation; older tokens are a finite compatibility window until normal expiry.
