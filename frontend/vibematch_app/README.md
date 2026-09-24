# FunKey Flutter client

This directory contains the production FunKey Flutter client. The historical
`vibematch_app` folder/package name is retained for compatibility.

## Architecture rules

- Backend domain services are durable authority; Flutter owns display/cache/UI state only.
- Feature REST/control-plane traffic must flow through:
  `Repository / feature service -> AppNetworkClient -> CanonicalNetworkTransport -> Dio`.
- Feature folders may not import `package:http`, `package:dio`, or raw `HttpClient`.
- `RoomSessionRepository` is the single Flutter room-state authority.
- Room media engines own WebRTC transport lifecycle only.
- Application realtime uses the single Go `funkey.v2` socket; mediasoup signaling is separate.
- Watch Party state is backend/Room-Control authoritative.
- Remote games load through the verified Game Platform HTML runtime; gameplay is not bundled as Flutter packages.
- Media v2 streams large uploads directly to object storage; Flutter does not transcode large media.
- Preserve the existing visual language unless a product/UI change is explicitly requested.

Architecture enforcement lives in `test/architecture/` and the repository CI.

## Important foundations

| Area | Path |
|---|---|
| canonical networking | `lib/foundation/networking/` |
| persistence | `lib/foundation/persistence/` |
| app source-of-truth registry | `lib/` source registry / feature repositories |
| room session | room feature repository/controller boundaries |
| room media | media engine abstractions |
| Watch Party | provider-neutral Watch Party domain/adapters |
| remote games | Game Platform runtime/bridge |
| media upload v2 | foundation streaming upload transport |
| Inbox | `lib/features/inbox/` |

## Networking

`CanonicalNetworkTransport` owns timeouts, bearer-token injection, request IDs,
W3C trace headers, cancellation, safe/idempotent retry behavior, normalized
errors, connection reuse and request metrics. A foundation compatibility facade
exists only as a migration seam and still delegates to the same Dio transport.

Do not create a feature-local HTTP client.

## Realtime

The client mints a connect capability before opening the application socket and
room-specific subscribe capabilities as needed. Reconnect/resume uses canonical
room snapshot/replay semantics. Do not add another application WebSocket manager.

## Inbox

Conversation pages are cursor-paged summaries and contain no message history.
Opening a chat fetches a bounded message window; older history is independently
cursor-paged. Realtime events update the active model after authoritative commit.

## Media

Images/video/audio uploaded through Media v2 use upload-session control and
streamed direct upload. Interactive image crop/preview may use bounded in-memory
data; large media must not be buffered wholesale in Dart memory.

## Remote games

Remote game bundles are HTTPS-only, manifest/version/SHA-256 verified and run
behind the narrow Host Bridge. Remote JavaScript never receives the FunKey bearer
token. Fail closed when bundle integrity/configuration is invalid.

## Local development

Install Flutter matching CI, then from this directory:

```bash
flutter pub get
flutter test
flutter analyze
flutter build web --release
```

Use the repository local-development guide for backend/realtime/media services.
Do not hand-edit `pubspec.lock`; dependency changes must resolve and commit a
consistent lockfile.

## Before changing architecture

Read:
- `../../docs/master-source-of-truth-architecture.md`
- `../../docs/architecture/service-boundaries.md`
- `../../docs/architecture/flutter-canonical-networking.md`
- the relevant feature/module documentation

Any new authority/cache/socket/network abstraction needs a regression or
architecture guard so it cannot silently become a second source of truth.
