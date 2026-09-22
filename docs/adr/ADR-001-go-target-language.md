# ADR-001: Go as target backend language

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

FastAPI currently owns most application behavior. The new platform needs high connection concurrency without discarding working domain code.

## Decision

Prefer Go for new high-throughput APIs, realtime gateway, presence, room orchestration, and suitable workers. Retain Python for current endpoints, ML/data work, scripts, and domains until a bounded migration passes parity tests. Retain TypeScript for the canonical mediasoup implementation.

## Consequences

Go services can be profiled and scaled independently. The team must maintain explicit cross-language contracts and avoid copying business authority into the gateway.

## Validation and change criteria

Do not treat adding a Go binary as domain migration. Require versioned contract, parity tests, rollback route, and observability before moving traffic.
