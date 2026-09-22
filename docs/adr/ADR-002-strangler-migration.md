# ADR-002: Strangler migration instead of a big-bang rewrite

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

A full rewrite would risk existing Flutter HTTP, WebSocket, media, and Alembic contracts.

## Decision

Migrate one bounded domain or transport surface at a time behind compatible routing. Keep FastAPI operational. Start Go gateway in foundation/shadow mode; promote only after replay, behavior parity, canary, and rollback are proven.

## Consequences

Temporary dual runtimes add operational cost, but failures can be isolated and rolled back. Durable ownership must have one writer at each stage.

## Validation and change criteria

Track each domain as NOT STARTED, FOUNDATION READY, SHADOWED, CANARY READY, or MIGRATED. Never claim migration based solely on scaffolding.
