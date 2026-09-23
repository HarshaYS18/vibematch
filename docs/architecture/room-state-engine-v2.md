# Room State Engine v2

**Owner:** Room Control  
**Status:** Chunk 20 implementation contract  
**Durable authority:** PostgreSQL  
**Ephemeral transport/replay:** realtime Redis/Valkey

## Goal

Make room state cheap to keep live, explicit to version, and safe to recover after reconnects without turning Redis or Flutter into a second source of truth.

The normal connected path is:

```text
socket alive
  -> refresh Redis socket lease
  -> no PostgreSQL room snapshot
```

PostgreSQL writes remain lifecycle/business writes: join, leave, membership, seats, settings, moderation, chat persistence, Watch Party/activity state, and less-frequent durable checkpoints.

## Three different counters

Do not conflate these:

- `rooms.realtime_version` is the durable authoritative room-state version. It advances with authoritative mutation events.
- `rooms.realtime_event_sequence` is the durable sequence of `room_realtime_events` used for audit/domain replay identity.
- realtime Redis `sequence` is a contiguous **transport** cursor for one `room:<room_id>:<epoch>` stream. It is ephemeral and exists only to detect/replay delivery gaps.

Every durable room event also has a stable `event_id`.

Redis loss may reset the transport epoch/sequence. It must never reset or overwrite the two PostgreSQL counters.

## Current-state tables

Current membership requests and seat applications are no longer reconstructed by scanning audit events.

- `room_member_requests` stores pending/decided membership request state.
- `room_seat_applications` stores pending/expired/decided seat application state.
- `room_realtime_events` remains audit/event history.

Migration `20260923_0200_room_state_engine_v2.py` backfills unresolved legacy requests from the existing event history before new code reads the dedicated tables.

## Snapshot contract

`room_snapshot()` is a read model. It must not:
- create missing seat rows;
- release orphaned seats;
- expire participants;
- mutate room counters;
- reconstruct pending membership/seat state from event-history scans.

Missing persisted seat rows are represented as empty seats in memory. Maintenance and cleanup are explicit write paths.

Snapshots expose both `state_version` and `event_sequence`.

## Presence

Room join/leave remain durable lifecycle edges. Normal connected liveness is represented by expiring Redis socket leases refreshed by the realtime connection manager.

The old periodic Flutter room-presence timer has been removed. Both room heartbeat HTTP compatibility routes are snapshot-free and perform no heartbeat state mutation.

Global/non-room presence APIs remain separate and are not a replacement for room socket leases.

## Delivery and recovery protocol

```text
join
  -> authoritative snapshot

normal mutation
  -> room-state-v2 delta

gap/reconnect with same Redis stream epoch
  -> replay contiguous missing events if still buffered

replay unavailable / epoch changed / buffer trimmed
  -> authoritative snapshot
```

Room transport replay is bounded to 256 events and five minutes. The stream epoch/sequence keys expire after 24 hours of inactivity. The buffer is a CACHE/EPHEMERAL projection only.

## Compatibility during migration

Chunk 20 does not perform the Chunk 21 one-Go-socket cutover.

During the compatibility window:
- legacy FastAPI room sockets may still receive the replacement `room` snapshot in an event;
- the Go/application-realtime Redis envelope removes that replacement snapshot when a v2 `delta` is present;
- `RoomSessionRepository` can reconcile full snapshots and partial v2 deltas;
- no second Flutter room-state manager is introduced.

Chunk 21 owns removal of the remaining feature-specific application sockets after parity.

## Failure semantics

If Redis sequencing/replay fails after a durable mutation commits, the mutation remains successful. Compatibility delivery may continue, but the event is marked `resync_required` and sequenced clients must fetch a PostgreSQL-backed snapshot.

If a replay request cannot prove a contiguous sequence through the current transport cursor, it fails closed to snapshot recovery.

## Observability

FastAPI exports:
- `funkey_room_replay_attempts_total`
- `funkey_room_replay_success_total`
- `funkey_room_replay_fallback_total`
- `funkey_room_sequence_failures_total`

Alert on sustained replay fallback or sequencing failures. Never label these metrics with room IDs or user IDs.

## Completion invariants

Chunk 20 is complete only when:
- no normal connected room heartbeat rebuilds a PostgreSQL snapshot;
- room snapshots are read-only;
- current membership/seat requests use dedicated tables;
- durable version/event identity is explicit;
- bounded replay has snapshot fallback;
- canonical application realtime carries v2 deltas;
- `RoomSessionRepository` remains Flutter room authority;
- migrations, backend tests, Flutter tests, architecture guard, and platform CI pass.
