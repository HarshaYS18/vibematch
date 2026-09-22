# Profiles

## Purpose and responsibilities

Exposes profile details, display preferences, visits, and privacy-sensitive profile views. The module owns profile display and visit records; user profile fields. Routes should validate input and delegate business decisions to services.

## Ownership and source of truth

PostgreSQL is the durable source of truth for users, user_stealth_states, profile_display_audits, profile_visits. This module does not own SFU transport state, edge routing, or client UI state. Flutter caches are replaced by backend snapshots.

## Important files and public contracts

`backend/app/services/profile_service.py`, `backend/app/services/profile_display_service.py`, `backend/app/api/routes/profile_display.py`. Public surface: profile and display routes under /api/v1. Preserve deployed request and response shapes while migrating implementation.

## Events published and consumed

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Database and Redis state

Database tables and state: `users, user_stealth_states, profile_display_audits, profile_visits`. Redis: Optional cache only; no durable profile authority.

## Dependencies and security

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services. Stealth and hidden-presence rules must be enforced before rendering a public profile. Never log tokens, OTPs, or payment secrets.

## Failure modes and retry behavior

Stale cache can disclose private data; invalidate or bypass on permission changes. Reads and writes should use bounded timeouts. Retries are safe only for read operations or writes backed by an idempotency key and known commit outcome.

## Scaling and observability

Scale stateless API replicas only within the PostgreSQL connection budget. Track route request rate, p95 latency, error rate, transaction latency, DB pool use, and domain-specific rejection counts. Trace commands through commit and fanout with a request ID; avoid user PII in metric labels.

## Local development and testing

Start dependencies with `.\\scripts\\dev-up.ps1`, then run affected backend tests with `python -m unittest discover -s backend/tests -p test_*.py` from the repository root with the backend import path configured, or use the test command in the root README. Add a regression test for authorization, transaction outcome, and duplicate/reconnect behavior when relevant.

## Deployment notes and change checklist

Apply Alembic first; roll out compatible API behavior; check readiness and error metrics. Before changing this module: identify the owning table and contract, add an additive migration if needed, preserve Flutter compatibility, verify permission checks, and document rollback. Known migration status: **Existing FastAPI domain; no Go migration started.**
