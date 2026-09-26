# Chunk 34 — Flutter Resource Runtime

**Status: COMPLETE through M14.**

## M1: session-scoped resource coordinator contract

Chunk 34 addresses Flutter resource pressure caused by persistent tabs and
simultaneous heavyweight resources such as Vibes video decoders, Watch Party
and game WebViews, room WebRTC, gift video, camera/mic, and game bundle caches.

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

`MediaResourceKind.flutterImageCache` represents Flutter's shared decoded
image-cache memory. The separate unused prefetch resource kind was retired after
the production graph showed no registered consumer.

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


## M8: OTT Watch Party WebView lifecycle

M8 migrates the embedded Netflix, Prime Video and JioHotstar WebView surface
through the M6 foundation resource registry.

### Ownership boundary

The room sheet continues to own the local provider adapter and
`InAppWebViewOttPlaybackHost`. Canonical Watch Party state, revision checks,
controller identity, timeline and commands remain in
`WatchPartyRepository`/backend. The lifecycle participant does not become a
second Watch Party authority.

### Registration timing

`InAppWebViewOttPlaybackHost` now exposes an optional readiness callback that
fires after a concrete platform WebView controller exists. The room sheet
registers `WatchPartyWebViewResourceParticipant` only from that callback.

This also covers WebView remounts after companion fallback. If the participant
is already registered, the remounted WebView is resynchronized to the
registry's current foreground state.

Normal sheet disposal unregisters the participant before
`WatchPartyCoordinator.dispose()` tears down the provider adapter/host.

### Lifecycle behavior

- background/inactive app state: best-effort pause of embedded OTT playback;
- foreground: no forced local play; canonical room reconciliation decides
  whether playback should resume;
- memory pressure: deliberately non-destructive because destroying/reloading an
  active provider WebView can interrupt entitlement/session playback;
- authenticated-session teardown: release/dispose the WebView host.

The existing sheet resume flow still refreshes the authoritative room snapshot,
restores provider state and reconciles the canonical timeline.

### DRM/provider safety

M8 adds no provider bypass, cookie extraction, DRM handling or credential
sharing. Existing runtime capability probing and companion fallback behavior
remain unchanged.


## M9: Room WebRTC lifecycle

M9 migrates the existing canonical `RoomMediaEngine` into the session resource
runtime without creating a second WebRTC/mediasoup owner.

### Ownership and minimized rooms

`LiveRoomMediaSignalingService` already owns the single
`RoomMediaEngine`. M9 keeps that ownership intact and injects the foundation
`MediaResourceRegistry` into the service when a live-room presence shell is
configured.

Registration is intentionally tied to the media service's actual room
configure/leave lifecycle rather than the room widget's dispose lifecycle.
FunKey can minimize a room while keeping media connected; route disposal must
therefore not unregister WebRTC prematurely.

### Resource participant

`RoomMediaResourceParticipant` lives under `room_media/runtime` and depends
only on the foundation lifecycle contract.

- foreground: reconnect the active engine when it has an active/joining media
  session;
- background: no forced mute/leave, preserving the user's seat/mic intent and
  existing foreground-service behavior;
- memory pressure: non-destructive, because dropping active WebRTC transports
  would break the live room;
- authenticated-session release: call `leave()`, not terminal `dispose()`,
  because the compatibility singleton owns a reusable engine instance across
  future authenticated sessions.

### Foreground cutover

In authenticated AppShell operation, media reconnect now flows through:

`AppShell → MediaResourceCoordinator → RoomMediaResourceParticipant → RoomMediaEngine.reconnect()`.

`LiveRoomMediaSignalingService` retains its application-realtime reconnect
logic. Its old direct media-engine foreground reconnect is now only a fallback
when no foundation resource registry exists, preserving isolated tests/previews
without double reconnecting production room media.

### Authority

Room membership, seats and permissions remain
`RoomSessionRepository`/backend authority. The media engine continues to own
only mediasoup/WebRTC transport and local media intent.


## M10: gift-video decoder lifecycle

M10 migrates the production gift-video decoder path used by
`CleanVideoGiftOverlay`. The older `video_gift_overlay.dart` implementation
is not mounted by the live-room gift composition and is intentionally not given
a second lifecycle owner.

### Ownership

Each active gift video remains widget-owned through its
`VideoPlayerController`. The new `GiftVideoResourceParticipant` only
coordinates that ephemeral decoder with the authenticated resource runtime.

The participant is identified by explicit room scope plus gift-slide id, so
simultaneous rooms cannot collide.

### Lifecycle

- background: pause and remember whether the gift was playing;
- foreground: resume only if lifecycle had paused an active gift;
- memory pressure: release the ephemeral decoder and finish the gift rather
  than retaining a large transient video allocation;
- authenticated-session teardown: same terminal release path.

Normal widget disposal unregisters first, then idempotently disposes the
controller.

### Authority

Gift settlement, wallet state, combo state and durable gift history remain
backend/`LiveRoomGiftController` authority. This migration affects only local
gift presentation resources.


## M11: microphone/audio-input lifecycle

M11 registers the actual `getUserMedia(audio)` capture at its real owner,
`LiveRoomAudioService`, rather than inventing a second microphone path.

### Binding path

The authenticated foundation registry is passed through a narrow
`RoomMediaResourceRegistryBinding` implemented by
`DelegatingMediasoupEngine` and forwarded by the mediasoup audio delegate.
Room UI therefore continues to depend only on `RoomMediaEngine`; it never
bypasses the canonical media boundary to reach `LiveRoomAudioService`.

### Capture lifetime

An `AudioInputResourceParticipant` is registered only after a real local
`MediaStream` has been acquired. It is unregistered when that stream is
stopped.

Active room voice is treated as high-priority media:

- app background: no forced mute/stop;
- memory pressure: no forced capture teardown;
- authenticated-session teardown: release the local microphone stream.

Normal mute/leave/seat transitions remain owned by the existing audio service
and continue to stop capture through the same canonical path.

### Authority

The resource participant does not decide whether the user may speak. Seat,
admin-mute and publish authorization remain backend/room authority.


## M12: camera-input lifecycle

M12 migrates the actual local camera track used by Inbox video calls.

### Ownership

`InboxCallMediaBridge` remains the owner of the combined local call
`MediaStream`, mediasoup producers/transports and call media lifecycle.
`CameraInputResourceParticipant` wraps only the video-input portion.

The active call page injects the foundation registry when creating its media
bridge; it does not import the concrete App coordinator.

### Lifecycle

- background: disable/pause the local camera only when it was enabled;
- foreground: resume only when lifecycle had paused an active camera;
- memory pressure: non-destructive, preserving an active video call;
- authenticated-session teardown: close the local video producer and stop the
  camera track while leaving call audio cleanup to the bridge's normal teardown.

A user-disabled camera is never auto-enabled by a later foreground transition.

### Authority

Inbox call session state remains Inbox/backend authority. The resource runtime
does not answer/end calls or alter call participants.


## M13: canonical AppImage decode pipeline

M13 establishes one native Flutter image path for high-frequency network/image
surfaces without adding a third-party cache package.

### AppImage

`foundation/images/app_image.dart` provides `AppImage.network` and
`AppImage.asset`. Decode targets are derived from logical render size and
device pixel ratio, capped by `AppImageDecodePolicy.maxDecodeDimension`.
This prevents small avatars/frames from decoding full-resolution uploads into
memory.

The first guarded migrations are:

- Vibes avatars;
- shared avatar-frame images;

These hot surfaces may no longer use raw `Image.network`/`NetworkImage`.

### Cleanup closure

M13's durable production value is per-widget decode sizing through `AppImage`.
The standalone prefetch queue was subsequently proven unreachable from
`main.dart`, production feature imports and native/config references, so it
was removed during repository minimization.

### Relationship to M5

M5 continues to own Flutter's shared decoded-image cache pressure. M13 retains
per-widget decode sizing only; there is no duplicate speculative prefetch
resource to coordinate.


### UI and authority

No user-visible layout is changed. Uploaded/profile image URLs remain owned by
their existing profile/content domains; the image runtime is presentation/cache
infrastructure only.


## M14: final closure

M14 closes Chunk 34 after auditing all heavyweight Flutter resource owners,
their registration lifetime, memory-pressure policy, authenticated-session
teardown, tests, guards and documentation.

### Final pressure policy

`media_resource_budget.dart` gives every `MediaResourceKind` an advisory
active-count budget and one of four pressure tiers: reclaim-first,
reconstructable, interactive, or realtime-critical. These values are
diagnostics, not destructive admission control.

The coordinator now processes pressure tier-by-tier, reclaiming speculative and
reconstructable work before realtime-critical room/call media. Lifecycle
callback failures are isolated per participant so one broken resource cannot
block cleanup of healthy resources.

### Capture completeness

Known concrete Flutter capture owners are now covered:

- live-room microphone;
- Inbox call microphone;
- Inbox call camera;
- room WebRTC transport.

The Inbox call microphone was found during the final audit and is now registered
as `MediaResourceKind.audioInput`.

### Closure repairs

The previous M11 room-media binding is explicitly cast through its optional
registry interface for compatibility with the current Dart toolchain. The M8
Watch Party lifecycle test imports the domain contract that defines
`WatchLiveTimeline`.

Gift-video async initialization disposes stale/failed controllers, failed Inbox
call startup performs best-effort teardown, and all retained resource participants are
wired to concrete production owners.

No further Chunk 34 micro-chunk remains after M14.


## Post-closure analyzer hygiene

A follow-up CI cleanup after Chunk 35 added the missing interface `@override`
annotations to `MediaResourceCoordinator` and normalized the budget error
message to Dart string interpolation. This change is analyzer-only and does not
alter lifecycle behavior, resource budgets, ownership, or pressure ordering.
