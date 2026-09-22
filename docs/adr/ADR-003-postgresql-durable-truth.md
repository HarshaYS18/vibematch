# ADR-003: PostgreSQL as durable source of truth

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

Identity, rooms, messages, bans, and value movement need transactional, replayable state. The checkpoint already has SQLAlchemy models and Alembic history.

## Decision

Keep one canonical PostgreSQL schema and Alembic migration graph. Domain services own transactions; Redis and events are derivatives. Wallet/ledger writes require atomicity and idempotency.

## Consequences

Pool capacity and hot query design become central scale constraints. Backups, PITR, failover drills, and explicit timeouts are required.

## Validation and change criteria

Do not create schema at process startup. Validate Alembic head before release and use the database outage/restore runbooks.
