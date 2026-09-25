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


## M4: verified game-bundle cache migration

M4 migrates the second reconstructable resource family: the in-memory verified
remote game bundle cache.

### Adapter boundary

`GameBundleCacheResourceParticipant` wraps the existing `GameBundleCache`.
Game manifest verification, integrity checks, catalog/version policy and cache
population remain owned by Game Platform. The resource adapter only clears the
warm cache when memory pressure or authenticated-session teardown requires it.

Foreground/background transitions are intentionally a no-op because verified
HTML bundle bytes are passive memory, not an active decoder/WebView.

### Cutover

AppShell creates the adapter around the existing
`gameBundleCacheProvider` instance and registers it idempotently with the same
session coordinator used for Vibes.

The old direct AppShell call
`ref.read(gameBundleCacheProvider).clear()` is removed, leaving one route:

`AppShell → MediaResourceCoordinator → GameBundleCacheResourceParticipant → GameBundleCache.clear()`.

Flutter image-cache cleanup remains direct and guarded for a later micro-chunk.

### Authority and safety

The cache contains only reconstructable, integrity-verified remote game bundle
content. Clearing it changes no durable game state, settlement, wallet state,
room state or game-session authority; the next launch reloads and verifies the
bundle through the canonical Game Platform repository.


## M5: Flutter decoded image-cache migration

M5 migrates the final heavyweight cleanup path that was still executed directly
inside AppShell: Flutter's live decoded/network image cache.

### Resource taxonomy

`MediaResourceKind.flutterImageCache` is added separately from
`imagePrefetch`. The former represents Flutter's shared decoded image-cache
memory; the latter is reserved for explicit feature-driven prefetch work that
may be introduced or migrated later.

### Adapter boundary

`FlutterImageCacheResourceParticipant` receives an injected
`clearLiveImages` callback. AppShell supplies
`PaintingBinding.instance.imageCache.clearLiveImages`, while tests can inject
a counter without depending on global Flutter cache internals.

Foreground/background transitions are a no-op. Memory pressure clears live
decoded images. Authenticated-session release performs the same trim once and
then makes the adapter terminal.

### Cutover

The direct AppShell image-cache call is removed. After M5, the three original
AppShell memory-pressure cleanup paths all converge through the coordinator:

- Vibes decoder arbitration → M3 participant;
- verified game-bundle cache → M4 participant;
- Flutter live image cache → M5 participant.

AppShell now only emits the memory-pressure signal and no longer knows how each
heavy resource performs cleanup.

### Authority and safety

Flutter's image cache contains reconstructable presentation memory only.
Clearing live entries changes no durable application state and does not alter
room, identity, wallet, Watch Party, game-session or content authority.


## M6: foundation resource registry boundary

M6 prepares Chunk 34 for feature-owned resources such as game WebViews, Watch
Party WebViews and room WebRTC without allowing those features to import
`app/runtime`.

### Foundation contract

`foundation/runtime/media_resource_lifecycle.dart` now owns:

- `MediaResourceKind`;
- `MediaResourceParticipant`;
- `MediaResourceRegistry`;
- nullable `mediaResourceRegistryProvider`.

The nullable default intentionally allows feature widgets to remain reusable
outside the authenticated AppShell (tests, previews or future isolated flows).

### App implementation

`MediaResourceCoordinator` remains under `app/runtime` and now implements the
foundation `MediaResourceRegistry`. Its auto-disposed provider, lifecycle
fan-out and terminal session cleanup remain unchanged.

Existing App-runtime adapters now import the foundation lifecycle contract
directly rather than relying on transitive types from the coordinator file.

### Authenticated subtree injection

AppShell wraps its existing UI subtree in a nested Riverpod `ProviderScope`
that overrides `mediaResourceRegistryProvider` with the current
session-scoped coordinator. There is no layout or visual change.

This creates the dependency direction required for later migrations:

`AppShell/app runtime → foundation registry port ← feature-owned resource`.

Feature code can now read the registry port and register its own resource
participant without importing or knowing about `MediaResourceCoordinator`.

### Guard

The architecture guard requires the foundation contract and rejects imports of
`media_resource_coordinator.dart` from features, Game Platform, Watch Party or
room media.


## M7: remote Game Platform WebView lifecycle

M7 migrates the first feature-owned heavyweight runtime through the M6
foundation registry: the verified remote Game Platform WebView.

### Ownership boundary

`GameWebViewResourceParticipant` lives inside `game_platform/runtime` and
depends only on `foundation/runtime/media_resource_lifecycle.dart`.
Game Platform continues to own the concrete `GameRuntime`,
`InAppWebViewController`, Host Bridge and durable game-session interaction.
The App resource runtime never becomes game-domain authority.

### Registration lifecycle

`RemoteGamePlayerPage` registers the participant only after
`InAppWebViewGameRuntime` reports that its concrete WebView controller has
been created. This avoids losing the coordinator's initial foreground/background
state before the WebView exists.

Normal page retry/reload and page disposal explicitly unregister the participant
before disposing the old runtime. Authenticated-session teardown remains safe:
the coordinator may call participant `release()`, and the underlying
`GameRuntime.dispose()` is idempotent.

### Lifecycle signals

The participant forwards non-authoritative host events through the existing
`GameRuntime.sendHostEvent` channel:

- `app.lifecycle` with `foreground: true|false`;
- `app.memory_pressure` when Flutter reports memory pressure.

These signals let remote game HTML voluntarily pause animation/audio or trim
reconstructable caches. M7 deliberately does **not** destroy/reload the WebView
on ordinary memory pressure, because that could interrupt an active round.

### Security and authority

No bearer token is exposed to remote HTML, no second WebSocket is created, and
game financial/durable state remains backend authority. The feature imports the
foundation registry port only; the architecture guard continues to reject
imports of the concrete App coordinator.
