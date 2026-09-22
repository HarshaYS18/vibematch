# ADR-010: Realtime gateway ownership

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

The existing FastAPI room system owns durable state; a Go gateway is being introduced for connection scale.

## Decision

The gateway owns authentication of a connection, live socket lifecycle, fanout, backpressure, reconnect/resume transport, registry metadata, and graceful drain. FastAPI/domain services retain decisions and writes for rooms, seats, bans, messages, and value.

## Consequences

The gateway may cache transient routing data, but correctness cannot depend on sticky load-balancer sessions or a single process's memory. On event gaps, clients fetch authoritative snapshots.

## Validation and change criteria

Keep it in shadow/foundation until Flutter contract and behavior parity are proven; drain tests must cover reconnect storms.
