# ADR-014: PostgreSQL transaction pooling and credential boundaries

**Status:** Accepted  
**Date:** 2026-09-23

## Context

FunKey already bounds SQLAlchemy pools, but pod autoscaling can still create too many PostgreSQL server connections. Later service extraction also requires independent database credentials without turning PostgreSQL into a shared unrestricted integration surface.

## Decision

Use PgBouncer transaction pooling for compatible application traffic. Keep migrations/DBA/session-semantic operations on a separate direct PostgreSQL DSN. Enforce separate client and server connection budgets.

Require statement, lock, and idle-in-transaction timeouts. Enable `pg_stat_statements` and standard PostgreSQL monitoring. Prepare one login/schema ownership boundary per extracted service and prohibit unrestricted cross-service writes after cutover.

## Consequences

Code cannot depend accidentally on arbitrary session state while using transaction pooling. Features that truly require session semantics need an explicit reviewed direct/session-pooled path.

A pooler outage affects availability but does not change business authority. PostgreSQL remains durable truth.

Service extraction gains a clear least-privilege path instead of sharing the monolith's database credential indefinitely.
