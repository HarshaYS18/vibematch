# Chunk 7 — Watch Party Core

Chunk 7 introduces the provider-independent Watch Party domain without changing
the existing room UI and without implementing YouTube, Netflix, Prime Video or
JioHotstar playback adapters.

## Ownership

```text
RoomSessionRepository
  owns canonical room snapshot projection
          |
          | watch_party projection
          v
WatchPartyRepository
  owns WatchSession command/reconciliation state
          |
          v
WatchPartyCoordinator
  owns provider-independent synchronization
          |
          v
WatchProviderAdapter
  future provider implementation boundary
```

The backend remains authoritative. Watch Party commands are persisted in the
existing sequenced `RoomRealtimeEvent` log and every mutation returns/broadcasts
a canonical room snapshot. No second Watch Party websocket or local authority is
introduced.

## Canonical WatchSession

The projected session contains:

- session id and room id
- provider
- content id / URL / title
- host user id
- controller user id
- playback state
- position in milliseconds
- authoritative server anchor time
- playback rate
- revision
- room event sequence
- active/ended state

Commands are LOAD, PLAY, PAUSE, SEEK, CHANGE_CONTENT, SYNC, END and
TRANSFER_CONTROL.

Mutating commands use optimistic `expected_revision` checks so a stale
controller cannot overwrite a newer authoritative timeline.

## Clock synchronization

The frontend never treats the host device clock as authoritative. It samples
`server_time` from canonical room snapshots, computes a server offset and
projects the target position from:

```text
position_ms + (server_now - server_anchor_time) * playback_rate
```

Drift policy in the core coordinator:

- <= 250 ms: ignore and restore authoritative playback rate
- 250–1499 ms while playing: temporary rate correction when supported
- >= 1500 ms: seek to the authoritative position
- paused drift above tolerance: seek, because rate correction cannot converge

Provider capabilities decide whether play, pause, seek, position reads and rate
correction are available.

## Controller departure

A Watch Party is not tied to the original host socket. If the current controller
leaves, is kicked, or becomes stale, the backend deterministically transfers
control to an active candidate in this order:

1. room owner
2. room admin
3. room member
4. remaining active participant

If nobody remains, the Watch Party ends.

## Explicitly deferred

Chunk 7 does not implement provider playback. Those remain dependency-ordered:

- Chunk 8: YouTube official player adapter
- Chunk 9: Netflix / Prime Video / JioHotstar companion adapters

No DRM bypass, provider scraping, browser injection, content restreaming or
shared-account playback is part of this architecture.
