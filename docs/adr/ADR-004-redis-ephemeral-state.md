# ADR-004: Redis/Valkey ephemeral-state policy

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

Presence, fanout, media registry, and short leases need shared low-latency coordination, while Redis can lose data during failover.

## Decision

Use Redis/Valkey for TTL presence, cache, routing, rate limits, reservations, and media assignment. Isolate application cache/rate-limit, realtime/presence, and media registry into separate failure domains as defined by ADR-015. PostgreSQL remains the record for identity, roles, bans, wallet, ledgers, and moderation history.

## Consequences

Consumers must tolerate cache loss and rebuild transient state. Key namespaces, TTLs, eviction policy, and capacity metrics are part of the contract.

## Validation and change criteria

Never infer a durable ban or balance only from a cache hit. Separate media registry topology is defined by ADR-008; role isolation and current Redis Cluster limitations are defined by ADR-015.
