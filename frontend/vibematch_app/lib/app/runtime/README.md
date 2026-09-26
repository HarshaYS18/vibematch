# App Runtime

Files in this directory are authenticated AppShell/session-scoped runtimes.
They coordinate cross-feature lifecycle or realtime wiring without becoming
parallel domain-state authorities.

## Resource coordination

`media_resource_coordinator.dart` is the Chunk 34 lifecycle registry for
heavy resources. It is created with Riverpod `Provider.autoDispose`, contains
no feature singleton, and owns no room/Watch Party/game/gift state.

Feature integrations must register adapters explicitly and preserve their
existing canonical repositories/controllers. Memory-pressure operations may
discard reconstructable/warm resources only; durable state is never stored
here.


## AppShell lifecycle bridge

Chunk 34-M2 makes AppShell the lifecycle bridge for
`MediaResourceCoordinator`. The shell keeps the auto-disposed provider alive
while authenticated and mirrors app foreground/background and memory-pressure
signals into it.

This is a mirror-only migration step. Existing direct Vibes decoder ownership,
Flutter image-cache cleanup, and game-bundle cache cleanup remain in AppShell
until their dedicated resource migrations are completed and guarded.


## Vibes resource participant

`vibes_media_resource_participant.dart` adapts the existing
`VibeMediaPlaybackGate` to the generic resource lifecycle contract. AppShell
owns the gate and registers the adapter with the session coordinator.

The adapter does not own feed selection or decoder/controller instances. It
only applies app-background pause pressure and forwards memory-pressure trims.


## Game bundle cache adapter

`game_bundle_cache_resource_participant.dart` is the Chunk 34-M4 lifecycle
bridge for Game Platform's verified in-memory bundle cache. It forwards memory
pressure/session release to `GameBundleCache.clear()` and deliberately does
nothing on foreground transitions because the cache is passive warm memory.


## Flutter image-cache adapter

`flutter_image_cache_resource_participant.dart` is the Chunk 34-M5 bridge for
Flutter's shared decoded image cache. It is callback-injected so runtime tests
remain deterministic and AppShell no longer contains direct image-cache cleanup
logic.


## Foundation registry port

From Chunk 34-M6 onward, the participant/registry interfaces and resource-kind
taxonomy live in `foundation/runtime/media_resource_lifecycle.dart`.
`MediaResourceCoordinator` is only the authenticated AppShell implementation.

AppShell exposes that implementation to descendants through a scoped
`mediaResourceRegistryProvider` override. Feature code must never import the
concrete coordinator.


## Chunk 34-M14 closure

The coordinator now uses `media_resource_budget.dart` for deterministic
pressure ordering and advisory over-budget diagnostics. Foreground, pressure and
session-release operations are isolated per participant, so one failing adapter
cannot prevent other resources from being cleaned up.
