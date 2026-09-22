# Games

## Purpose and responsibilities

Runs game definitions, rounds, bets, pool settlement, and risk audit. The module owns game_definitions, game_rounds, game_bets, game_pools, game_risk_audits. Routes should validate input and delegate business decisions to services.

## Ownership and source of truth

PostgreSQL is the durable source of truth for game_definitions, game_rounds, game_bets, game_pools, game_risk_audits, wallet_ledger. This module does not own SFU transport state, edge routing, or client UI state. Flutter caches are replaced by backend snapshots.

## Important files and public contracts

`backend/app/services/game_service.py`, `backend/app/services/game_settlement_service.py`, `backend/app/api/routes/games.py`. Public surface: game and settlement routes under /api/v1. Preserve deployed request and response shapes while migrating implementation.

## Events published and consumed

Current code may emit domain WebSocket updates after committed writes. A versioned broker event for this domain must be added only with a contract and transactional publication path; do not claim every proposed event is live. Consumers must handle duplicates and refetch a snapshot after a gap.

## Database and Redis state

Database tables and state: `game_definitions, game_rounds, game_bets, game_pools, game_risk_audits, wallet_ledger`. Redis: Live score fanout may be cached; stakes and results remain durable.

## Dependencies and security

Depends on FastAPI authentication, SQLAlchemy transaction/session handling, and the relevant domain services. Server RNG, bet limits, settlement permissions, and value ledger are authoritative. Never log tokens, OTPs, or payment secrets.

## Failure modes and retry behavior

Round settlement must be idempotent and recover from interrupted execution. Reads and writes should use bounded timeouts. Retries are safe only for read operations or writes backed by an idempotency key and known commit outcome.

## Scaling and observability

Scale stateless API replicas only within the PostgreSQL connection budget. Track route request rate, p95 latency, error rate, transaction latency, DB pool use, and domain-specific rejection counts. Trace commands through commit and fanout with a request ID; avoid user PII in metric labels.

## Local development and testing

Start dependencies with `.\\scripts\\dev-up.ps1`, then run affected backend tests with `python -m unittest discover -s backend/tests -p test_*.py` from the repository root with the backend import path configured, or use the test command in the root README. Add a regression test for authorization, transaction outcome, and duplicate/reconnect behavior when relevant.

## Deployment notes and change checklist

Apply Alembic first; roll out compatible API behavior; check readiness and error metrics. Before changing this module: identify the owning table and contract, add an additive migration if needed, preserve Flutter compatibility, verify permission checks, and document rollback. Known migration status: **Existing FastAPI domain; no Go migration started.**
