# ADR-011: Database connection budget

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

Autoscaling pods without a connection cap can exhaust PostgreSQL before CPU or latency signals trigger.

## Decision

Budget connections as maximum_pods × pool_size_per_pod plus worker, migration, admin, monitoring, and failover reserves <= allowed_backend_connections. Use PgBouncer or managed pooling where appropriate, bounded acquisition, statement, lock, and connect timeouts.

## Consequences

HPA maximum is constrained by the budget until measured pool behavior supports a new limit. A gateway with no direct DB need should not open idle pools.

## Validation and change criteria

Before increasing replicas, calculate the worst-case connections across rollout surge and failover. Track pool checkout waits, active connections, and rejected connections.
