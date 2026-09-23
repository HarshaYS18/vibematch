# ADR-017: One application WebSocket through the Go realtime gateway

**Status:** Accepted  
**Date:** 2026-09-23

## Context

FunKey accumulated separate application realtime paths for Inbox, rooms, and feature-specific updates. Each path duplicates reconnect logic, leases, ordering, backpressure, and lifecycle state. This increases memory, battery, race conditions, and server connection pressure.

## Decision

Use one authenticated Go WebSocket per application client for all non-media realtime traffic. Mediasoup signaling remains separate.

The Go gateway is transport only. FastAPI/domain services remain authoritative and publish events to the canonical realtime Redis channel. Room subscriptions are explicitly authorized. User, user-set, staff, global, and room scopes are supported.

Migrate by expand/mirror/compare/canary/soak before removing FastAPI application sockets. Feature code must not create new independent application WebSockets.

## Consequences

Reconnect, sequencing, drain, reauthorization, and backpressure are centralized. Features become subscribers rather than socket owners.

Redis/gateway failure can delay or lose ephemeral delivery, but authoritative REST snapshots and domain state remain recoverable.

The gateway requires stricter queueing, dedupe, routing, load tests, and observability because it becomes the shared application transport.
