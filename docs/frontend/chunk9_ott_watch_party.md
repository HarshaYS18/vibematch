# Chunk 9 — OTT Watch Party

## Status

Chunk 9 extends the canonical Watch Party core to Netflix, Prime Video, and
JioHotstar without creating a second Watch Party repository, websocket, or
timeline authority.

The provider strategy is capability driven:

```text
canonical WatchSession
        |
WatchPartyCoordinator
        |
WatchProviderAdapter
        |
desktop-Chrome-style WebView attempt
        |
runtime capability probe
      /     \
 embedded   companion/native-app fallback
```

The backend WatchSession remains authoritative in every mode.

## Providers

Canonical provider IDs:

- `netflix`
- `prime_video`
- `jiohotstar`

Aliases are normalized at the backend and provider-catalog boundaries.

Provider-specific repositories are deliberately not introduced.
`WatchPartyRepository` remains the only Watch Party command repository.

## Embedded playback boundary

The WebView implementation lives under:

```text
lib/watch_party/providers/web/
```

The room presentation does not manipulate `InAppWebViewController`
directly.

The main types are:

- `DesktopChromeBrowserProfile`
- `OttProviderDefinition`
- `OttPlaybackProbeResult`
- `OttJavascriptBridge`
- `Html5VideoPlaybackDriver`
- `OttWebPlaybackHost`
- `SupportedWebPlaybackAdapter`

`DesktopChromeBrowserProfile` centralizes the desktop Chrome-style user
agent and WebView settings so providers do not duplicate browser
configuration.

Changing the user agent is not treated as proof of desktop-Chrome
compatibility.

## Runtime capability probe

Embedded mode is advertised only after the runtime confirms a usable HTML5
player and the controls needed by the canonical coordinator.

The probe records capabilities such as:

- provider page availability
- player availability
- actual playback readiness
- readable position
- programmatic play
- programmatic pause
- programmatic seek
- playback-rate control
- fine-grained playback-rate control
- live seekable timeline availability

A provider page merely loading is not enough to mark embedded playback as
supported.

If a page is usable but login/player startup has not happened yet, the adapter
stays in `probing` mode so the participant can authenticate with their own
provider account and retry.

If the runtime is unsupported or playback fails, the adapter moves to
`companion` mode.

## Companion fallback

Companion mode is first class, not an error-only placeholder.

The canonical WatchSession stays active while the client opens the external
provider app or browser with `url_launcher`.

On app resume the room snapshot is refreshed and the provider adapter attempts
embedded reconciliation again.

FunKey room voice, chat, seats, gifts, presence, and room membership remain
independent from OTT playback.

Mobile operating systems may suspend or alter background audio while an
external provider app is foregrounded; no assumption is made that the OS will
preserve microphone/media behavior.

## Live timeline

Chunk 9 adds explicit:

```text
WatchTimelineMode.vod
WatchTimelineMode.live
```

and:

```text
targetLiveLatencyMs
```

The default target is:

```text
10000 ms
```

For live playback, the coordinator uses the last HTML5 `seekable` range when
available and targets:

```text
liveEdge - targetLiveLatencyMs
```

clamped into the seekable window.

It does not use `video.duration` as the live edge.

Live convergence is best effort. Different clients can still have different
CDNs, manifests, ad insertion, buffers, DRM pipelines, and seekable windows.

When a reliable live timeline is unavailable the provider cannot claim live
embedded synchronization capability and falls back to the appropriate
degraded/companion behavior.

## Controller model

The backend remains authoritative for:

- LOAD
- PLAY
- PAUSE
- SEEK
- CHANGE_CONTENT
- SYNC
- END
- TRANSFER_CONTROL

Every mutation continues to use `expected_revision`.

Local WebView controls never change the canonical WatchSession by themselves.

VOD controller controls are capability driven.

For live sessions the UI favors room resync to the configured live target
instead of arbitrary seeking.

## Private-room rule

OTT Watch Party is server restricted to FunKey's invite-only `Secret Vibe`
room mode.

Frontend `RoomPrivacyMode.privateVibe` mirrors this requirement for
presentation, but the frontend is not the security boundary.

The backend:

- rejects OTT LOAD in non-private rooms
- rejects OTT mutations when the room no longer satisfies the private rule
- redacts private OTT metadata from snapshots after privacy downgrade
- ends/redacts an active OTT session when room privacy is changed away from
  Secret Vibe

YouTube remains available under its existing room rules.

## Authentication, cookies, and DRM boundary

Each participant authenticates directly with Netflix, Prime Video, or
JioHotstar using their own provider account.

FunKey does not receive or redistribute:

- provider passwords
- provider cookies
- provider local-storage dumps
- DRM license payloads
- protected media manifests for bypass
- protected media streams

The implementation does not depend on private Netflix React/player internals
or equivalent private provider APIs.

The HTML5 driver only uses standard browser media APIs that are exposed to the
page runtime.

No DRM circumvention is part of Chunk 9.

## Flutter Web

`flutter_inappwebview` web support is bootstrapped in `web/index.html`.

Its web implementation uses an iframe and browser same-origin restrictions can
prevent cross-origin JavaScript player control. That is expected to fail the
runtime capability probe and move the client to companion mode rather than
falsely advertise embedded playback.

Native Android/iOS WebViews are also probed at runtime; support is never
inferred from desktop-browser behavior alone.

## Room UI

The existing Watch Party entry point is preserved.

A provider router now opens:

- existing YouTube sheet
- Netflix OTT sheet
- Prime Video OTT sheet
- JioHotstar OTT sheet

The inactive room layout and visual hierarchy are unchanged.

The OTT sheet reuses the existing FunKey bottom-sheet visual language and
shows only the state/actions required by the provider runtime.

## Tests and guards

Chunk 9 adds coverage for:

- provider URL allowlists
- provider aliases
- capability probe readiness
- embedded mode selection
- companion fallback
- external provider launch
- live-edge convergence
- live seekable-window clamping
- provider-independent source of truth
- absence of protected-provider bypass hooks

The architecture guard confines raw `flutter_inappwebview` usage to the
Watch Party web-provider boundary and keeps `InAppWebViewController` inside
`OttWebPlaybackHost`.

## Deferred

This chunk does not:

- guarantee that a specific OTT provider will permit embedded playback on
  every OS/WebView version
- bypass provider DRM or entitlement checks
- share provider credentials between participants
- redistribute one user's stream to other participants
- introduce Redis as an additional WatchSession authority

Redis/horizontal realtime scaling should reuse the canonical room realtime
control plane if it is needed later; it must not become a second WatchSession
source of truth.


## Chunk 34 resource lifecycle integration

The embedded OTT WebView is now registered as a feature-owned heavyweight
resource through `foundation/runtime/media_resource_lifecycle.dart`.

`LiveRoomOttWatchPartySheet` owns the host/adapter and registers
`WatchPartyWebViewResourceParticipant` only after
`InAppWebViewOttPlaybackHost` reports a concrete WebView controller. Normal
sheet disposal unregisters the resource before provider teardown.

App backgrounding triggers a best-effort local pause. Foreground does not
directly resume playback; the existing authoritative room snapshot refresh and
`WatchPartyCoordinator` reconciliation decide whether playback should resume.
Memory pressure does not destroy/reload the provider WebView. Session teardown
may release the WebView host.

This lifecycle integration does not change provider authentication, DRM,
capability probing, companion fallback, private-room enforcement or canonical
WatchSession ownership.
