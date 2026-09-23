# ADR-016: Room State Engine v2

**Status:** Accepted  
**Date:** 2026-09-23

## Context

The previous room path used periodic HTTP/WebSocket heartbeat traffic to refresh PostgreSQL rows and rebuild large room snapshots. Snapshot reads could also create/clean seats, expire stale state, and derive current requests by scanning event history. This couples liveness to expensive durable work and scales poorly.

## Decision

PostgreSQL remains Room Control authority. Redis/Valkey becomes the live presence and bounded transport-replay layer.

Persist `rooms.realtime_version`, `rooms.realtime_event_sequence`, and stable room-event `event_id`. Store current membership requests and seat applications in dedicated PostgreSQL tables. Keep `room_realtime_events` as audit/event history rather than a current-state query engine.

Normal socket liveness refreshes an expiring Redis lease and performs no room snapshot. Snapshot reads are side-effect free.

Use a separate contiguous Redis transport sequence scoped by stream epoch. Replay is bounded; inability to prove continuity falls back to the authoritative snapshot.

During migration, FastAPI compatibility room sockets may retain full replacement room payloads while the canonical application-realtime envelope is delta-first. The one-Go-socket client cutover is Chunk 21.

## Consequences

Redis failure can cause reconnects and snapshot fallback but cannot lose durable room truth. Transport sequence is intentionally not the durable event sequence.

Room mutations still construct a canonical response for existing HTTP/legacy compatibility contracts in Chunk 20; future optimization may compute narrower projections once compatibility consumers are removed.

The Flutter `RoomSessionRepository` remains the only canonical room client authority.
