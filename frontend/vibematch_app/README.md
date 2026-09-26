# FunKey Flutter client architecture

The directory/package name `vibematch_app` is retained for source compatibility;
the product is FunKey. This client preserves the existing UI while using
backend-authoritative domain state.

Supported Flutter targets are Android, iOS and Web. Desktop runner scaffolding
(Linux, macOS and Windows) is intentionally not kept in this client repository.

## Authority model

Flutter owns presentation, navigation, short-lived view models and reconstructable
cache state. It does not own identity/session truth, room membership/permissions,
wallet/ledger, gifts/purchases, game settlement, moderation, Inbox durability,
Vibes durability or Watch Party canonical playback state.

`RoomSessionRepository` remains the single client room-state authority. Do not
create a competing room singleton or feature-local global bus.

## Networking

Feature traffic follows:

```text
feature repository/service
  -> AppNetworkClient
  -> CanonicalNetworkTransport
  -> Dio
```

Feature folders may not instantiate raw Dio/http/HttpClient. The canonical
transport owns bearer injection, request/trace IDs, cancellation, timeouts,
connection reuse, retry safety and normalized errors.

## Realtime and media

There is one application WebSocket: the Go `funkey.v2` gateway. Room/inbox/
wallet events reconcile back to authoritative snapshots after reconnect.

mediasoup signaling is separate because it is media transport, not a second
application state channel. The room media engine owns WebRTC transport lifecycle
only.

## Watch Party

Provider adapters control YouTube or approved OTT companion/embedded behavior,
but Room Control remains canonical for playback revision, host authority and
late-join/reconnect reconciliation. Provider limitations must fail to companion
mode rather than bypassing DRM or permissions.

## Remote games

Games are CDN/HTML runtime assets verified by manifest/version/SHA-256 and loaded
behind the narrow game Host Bridge. Remote JavaScript never receives the FunKey
bearer token. Gameplay/settlement authority remains Game Platform + Economy.

## Persistence and offline behavior

Persistent client storage is reconstructable. The bounded offline projection may
cache small Home/public-profile/room-preview/Vibe/recent-search payloads.
Authoritative wallet, gift, purchase, membership, seat, moderation, auth and
settlement commands are never queued offline.

## Heavy resource lifecycle

The authenticated AppShell owns one session-scoped resource coordinator for video
decoders, WebViews, WebRTC, image cache, verified game bundles and related
memory-pressure/background lifecycle. Feature code registers participants rather
than creating a second coordinator.

## State management

Riverpod is the app-wide composition mechanism. Prefer selective provider
watching and immutable state. Persistent tab branches remain mounted to preserve
scroll/navigation state; inactive branches disable tickers and interaction.

## Performance rules

- one active Vibes decoder
- one canonical room WebRTC engine
- bounded image/game-bundle caches
- lazy lists and resized thumbnails
- no duplicate network fetches for the same canonical state
- background/low-power mode disables speculative prefetch
- profile before optimizing; do not hide latency with retries

## Local development

From this directory:

```bash
flutter pub get
flutter test
flutter analyze
flutter build web --release
```

Dependency changes must update and commit `pubspec.lock`. Use the repository
local-development guide for backend/realtime/media dependencies.

## Architecture change checklist

Before adding a cache, socket, singleton, persistence layer or network client:

- identify the existing authority
- use the canonical foundation abstraction
- add regression/architecture tests
- update module/architecture docs and compatibility notes
- preserve the existing visual design unless product explicitly changes it
