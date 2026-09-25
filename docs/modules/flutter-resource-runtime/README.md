# Flutter Resource Runtime

This module documents the AppShell/session-scoped runtime that coordinates
heavy Flutter resources.

## Source of truth

The resource runtime is **not** a domain source of truth. It coordinates
lifecycle pressure only. Domain authorities remain unchanged:

- room state: `RoomSessionRepository`;
- room media: `RoomMediaEngine`;
- Watch Party: its canonical repository/coordinator;
- games: Game Platform runtime/bridge;
- identity/session/realtime: their existing canonical repositories/runtimes.

## Lifecycle rules

Heavy resource owners register a small adapter with
`MediaResourceCoordinator`. The coordinator may broadcast app
foreground/background changes, memory pressure, and authenticated-session
teardown. Feature owners still create, mutate, and normally dispose their own
resources.

The coordinator itself is provided through Riverpod `Provider.autoDispose`;
a process-global singleton is forbidden.

## Current rollout

Chunk 34 is complete through M14. Vibes decoders, Game and Watch Party WebViews,
room WebRTC, gift video, live-room and Inbox-call microphone capture, Inbox call
camera input, Flutter image cache, image prefetch and verified game-bundle cache
are represented by the authenticated-session resource runtime.


## M2 AppShell mirror

AppShell watches `mediaResourceCoordinatorProvider` for the authenticated
session lifetime and forwards foreground/background plus memory-pressure
signals. Existing Vibes, image-cache, and game-cache cleanup remains active
during this mirror phase.

Lifecycle forwarding is best-effort and failure-isolated; it must never replace
canonical session reconciliation or introduce domain state into the resource
runtime.


## M3 Vibes migration

Vibes is the first migrated resource. App runtime wraps
`VibeMediaPlaybackGate` in `VibesMediaResourceParticipant`; the feature layer
does not depend on the coordinator.

Background lifecycle uses a dedicated pause lock so it composes with the
existing tab-pause state. Memory pressure flows through the coordinator exactly
once. Image and game cache cleanup remain on their existing direct paths.


## M4 verified game-bundle cache

`GameBundleCacheResourceParticipant` migrates the Game Platform's verified
in-memory bundle cache onto the coordinator. Memory pressure and session
teardown clear only reconstructable cached HTML bundles; catalog, manifest,
integrity and game-session authority remain in Game Platform.

AppShell no longer clears `gameBundleCacheProvider` directly after M4.
Flutter image-cache cleanup is still direct until its dedicated migration.


## M5 Flutter image cache

`FlutterImageCacheResourceParticipant` migrates the last direct AppShell
memory-pressure cleanup path. AppShell injects Flutter's existing
`ImageCache.clearLiveImages` callback and registers the participant beside the
Vibes and game-cache adapters.

The resource kind is `flutterImageCache`; explicit image-prefetch jobs remain
a separate `imagePrefetch` category for later work.


## M6 feature registration boundary

Feature-owned heavy resources must depend on
`foundation/runtime/media_resource_lifecycle.dart`, never on the concrete
AppShell coordinator.

The authenticated AppShell injects its session coordinator through
`mediaResourceRegistryProvider` using a nested `ProviderScope`. This allows
Game Platform, Watch Party and room media to register lifecycle participants
while preserving foundation → feature → app dependency direction.


## M7 remote game WebView

Game Platform is the first feature-owned runtime registered through the M6
foundation port. `RemoteGamePlayerPage` registers a
`GameWebViewResourceParticipant` when its concrete WebView becomes ready and
unregisters it before normal runtime disposal/retry.

The participant forwards app lifecycle and memory-pressure notifications through
the existing host-event bridge and releases the runtime on authenticated-session
teardown. It does not own rounds, bets, settlement or game session state.


## M8 OTT Watch Party WebView

Embedded Netflix, Prime Video and JioHotstar WebViews now register through the
foundation lifecycle port using `WatchPartyWebViewResourceParticipant`.

Registration occurs only after a concrete WebView controller exists. Background
lifecycle best-effort pauses embedded playback; foreground does not force play
because canonical Watch Party reconciliation remains authoritative. Memory
pressure is non-destructive, and authenticated-session teardown releases the
host.


## M9 Room WebRTC

The existing room `RoomMediaEngine` is now represented by
`RoomMediaResourceParticipant`. The room signaling owner registers it through
the foundation lifecycle port and keeps registration alive while a room is
minimized.

Foreground lifecycle reconnects the active WebRTC engine. Background and memory
pressure are non-destructive. Session teardown calls `leave()` rather than
terminally disposing the reusable singleton-owned engine.


## M10 gift-video decoder

The mounted `CleanVideoGiftOverlay` now registers each active
`VideoPlayerController` through a feature-owned
`GiftVideoResourceParticipant`. Backgrounding pauses the ephemeral gift,
foreground resumes only when appropriate, and memory pressure/session teardown
may drop the decoder and finish the presentation.

Gift settlement and wallet/domain state are unchanged.


## M11 microphone input

The concrete `getUserMedia(audio)` stream now registers as
`MediaResourceKind.audioInput` only while capture exists.
Registry injection reaches the legacy low-level audio implementation through
the canonical RoomMediaEngine/delegate boundary.

Background and memory pressure do not silently mute active room voice. Session
teardown releases the local input device.


## M12 camera input

Inbox video calls now expose the local camera as
`MediaResourceKind.cameraInput`. Background lifecycle pauses only the camera,
preserving call audio, and foreground resumes only if lifecycle performed that
pause. Memory pressure is non-destructive; session teardown releases the
camera track.


## M13 AppImage + prefetch

High-frequency image surfaces now use the foundation `AppImage` wrapper for
device-pixel-ratio-aware bounded decoding. A bounded
`AppImagePrefetchQueue` registers as `MediaResourceKind.imagePrefetch`, with
2 active and 12 queued requests maximum.

Background, memory pressure and session teardown invalidate speculative queued
work. In-flight work that finishes after invalidation is evicted. The shared
Flutter image cache remains independently managed by the M5 participant.


## M14 closure

Every resource kind now has an advisory budget and pressure tier. The
coordinator performs tiered memory-pressure cleanup and isolates failures per
participant. The final audit also adds the Inbox-call microphone and verifies
that speculative image prefetch stays scoped to the AppShell registry.
