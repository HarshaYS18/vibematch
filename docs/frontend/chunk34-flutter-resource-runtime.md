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


## M2: AppShell lifecycle mirror wiring

M2 wires the authenticated AppShell lifecycle into the coordinator without
moving ownership of any heavy resource.

### AppShell integration

AppShell now keeps `mediaResourceCoordinatorProvider` alive for exactly the
authenticated-shell lifetime and mirrors:

- memory pressure → `MediaResourceCoordinator.handleMemoryPressure()`;
- resumed lifecycle → `setForeground(true)`;
- inactive/paused/hidden/detached lifecycle → `setForeground(false)`.

Coordinator notifications are failure-isolated in AppShell helpers. A
participant failure is logged and cannot block the existing canonical session
reconciliation path.

### Mirror-mode freeze

M2 intentionally retains the existing proven cleanup behavior:

- `VibeMediaPlaybackGate.handleMemoryPressure()`;
- Flutter live image-cache clearing;
- `GameBundleCache.clear()`.

The architecture guard freezes those direct paths in place until each resource
owner is migrated in its own later micro-chunk. This prevents a premature
cutover from creating memory regressions.

### Behavioral impact

There is no user-visible/UI change in M2. Because no resource participant is
registered yet, the coordinator lifecycle broadcast is currently inert. M2 is
the mirror step that establishes the production lifecycle entry point before
resource-by-resource migration.


## M3: Vibes decoder lifecycle migration

M3 migrates the first real heavyweight resource family: Vibes feed video
decoder lifecycle.

### Adapter boundary

`VibesMediaResourceParticipant` lives in `app/runtime` and wraps the existing
`VibeMediaPlaybackGate`. This keeps dependency direction clean: feature code
does not import App runtime.

The adapter:

- acquires a dedicated app-background pause lock when the authenticated app is
  not foregrounded;
- releases only that lock on foreground, so the existing tab-pause lock still
  wins when Vibes is not the active tab;
- forwards memory pressure to the existing gate, which clears active decoder
  ownership and nudges distant players to dispose;
- on session release, pauses Vibes and triggers one final memory-pressure trim.

### Cutover

AppShell registers the adapter idempotently with the session coordinator. On
first registration it synchronizes the participant to the coordinator's current
foreground state, covering registration that occurs after an earlier lifecycle
transition.

The previous direct
`_vibePlaybackGate.handleMemoryPressure()` AppShell call is removed. Vibes
memory pressure now has one lifecycle route:

`AppShell → MediaResourceCoordinator → VibesMediaResourceParticipant → VibeMediaPlaybackGate`.

Image-cache and game-bundle cleanup remain direct and frozen for later
micro-chunks.

### No UI/state authority change

Vibes playback arbitration remains owned by `VibeMediaPlaybackGate`, and
individual `VideoPlayerController` instances remain widget-owned. The
coordinator does not select feed items, choose autoplay, or own video state.
