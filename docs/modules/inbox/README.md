# Inbox

## Purpose and responsibilities

Owns durable conversations, messages, participant state, calls, and inbox preferences. The module owns inbox_conversations, inbox_participants, inbox_messages, call_sessions, call_participants. Routes should validate input and delegate business decisions to services.

## Ownership and source of truth

PostgreSQL is the durable source of truth for inbox_conversations, inbox_participants, inbox_messages, call_sessions, call_participants. This module does not own SFU transport state, edge routing, or client UI state. Flutter caches are replaced by backend snapshots.

## Important files and public contracts

`backend/app/services/inbox_service.py`, `backend/app/services/inbox_call_service.py`, `backend/app/api/routes/inbox.py`. Public surface: /api/v1/inbox and calls routes; inbox WebSocket route. Preserve deployed request and response shapes while migrating implementation.

## Events published and consumed

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Database and Redis state

Database tables and state: `inbox_conversations, inbox_participants, inbox_messages, call_sessions, call_participants`. Redis: Transient typing/fanout only; messages stay in PostgreSQL.

## Dependencies and security

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services. Recipient eligibility, blocks, call participation, and attachment authorization are server decisions. Never log tokens, OTPs, or payment secrets.

## Failure modes and retry behavior

On missed delivery, clients reload conversation history and unread state. Reads and writes should use bounded timeouts. Retries are safe only for read operations or writes backed by an idempotency key and known commit outcome.

## Scaling and observability

Scale stateless API replicas only within the PostgreSQL connection budget. Track route request rate, p95 latency, error rate, transaction latency, DB pool use, and domain-specific rejection counts. Trace commands through commit and fanout with a request ID; avoid user PII in metric labels.

## Local development and testing

Start dependencies with `.\\scripts\\dev-up.ps1`, then run affected backend tests with `python -m unittest discover -s backend/tests -p test_*.py` from the repository root with the backend import path configured, or use the test command in the root README. Add a regression test for authorization, transaction outcome, and duplicate/reconnect behavior when relevant.

## Deployment notes and change checklist

Apply Alembic first; roll out compatible API behavior; check readiness and error metrics. Before changing this module: identify the owning table and contract, add an additive migration if needed, preserve Flutter compatibility, verify permission checks, and document rollback. Known migration status: **Existing FastAPI domain; worker delivery is a future boundary.**
