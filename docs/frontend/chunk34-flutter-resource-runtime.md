# Chunk 34 — Flutter Resource Runtime

## M1: session-scoped resource coordinator contract

Chunk 34 addresses Flutter resource pressure caused by persistent tabs and
simultaneous heavyweight resources such as Vibes video decoders, Watch Party
and game WebViews, room WebRTC, gift video, camera/mic, image prefetches, and
game bundle caches.

M1 is deliberately an **expand-only** step. It adds the coordinator contract
and lifecycle registry without changing UI or moving any existing resource
ownership yet.

### Ownership

`MediaResourceCoordinator` is lifecycle coordination only. It is **not** a new
source of truth for rooms, Watch Party, games, gifts, playback state, identity,
wallet, or any other domain. Existing repositories/controllers remain
authoritative.

The coordinator is created by
`Provider.autoDispose<MediaResourceCoordinator>`, so its registry is scoped to
the authenticated AppShell/session and cannot leak across logout or account
replacement.

### M1 contract

Registered feature adapters expose:

- a stable `resourceId`;
- a `MediaResourceKind`;
- foreground/background handling;
- memory-pressure trimming;
- terminal idempotent release.

Registration rejects two different participants sharing the same id. A stale
owner can unregister only its own participant reference. Session teardown
releases anything still registered.

### Migration

M1 does not integrate existing Vibes, Watch Party, game, WebRTC, gift, audio,
camera, image, or cache resources. Later micro-chunks will migrate those
resources one class at a time using the existing
expand → mirror → freeze/remove → guard discipline.

### Validation

M1 includes focused coordinator tests and architecture rules requiring:

- an auto-disposed session-scoped provider;
- no `MediaResourceCoordinator.instance`;
- no static coordinator singleton.

### Rollback

Because M1 is inert, rollback is limited to removing the coordinator contract,
its tests/docs, and its architecture rule. No feature behavior or persisted
state changes are introduced.
