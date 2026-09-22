# ADR-008: Dedicated HA single-primary Redis for media registry

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

The current Lua resolver scans a node index and reads dynamic node, reservation, and room keys. Redis Cluster would require all script keys in one hash slot; the current layout does not provide that.

## Decision

Keep the media registry on a dedicated highly available single-primary Redis/Valkey service with replica/failover. Do not enable Redis Cluster for these keys. Reserve capacity and monitor failover and script latency.

## Consequences

A single primary is an intentional atomicity boundary and potential throughput limit. Capacity tests must measure registry operations. Failover can invalidate transient assignments and clients must re-resolve.

## Validation and change criteria

A future Cluster redesign needs hash-slot-safe keys/scripts and tests for atomic selection, reservations, heartbeat, drain, and failover before this decision changes.
