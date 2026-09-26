# Final decommissioning and legacy policy

Chunk 56 does not delete code because a filename contains "legacy". A path is
removed only when reachability, compatibility and migration evidence show that
its replacement is authoritative.

Confirmed **path removals** are recorded in
`contracts/decommission/decommission-registry-v1.json`. They include:

- the obsolete Android `com.example.vibematch_app` activity/service copy after
  the namespace/applicationId moved to `com.funkey.app`;
- bundled Jungle Hunt game artwork that was outside the Flutter asset manifest
  and conflicted with the verified CDN/HTML remote-game architecture.

Dependency cleanup is governed separately by the dependency-hygiene policy. In
this chunk the obsolete direct Flutter `package:http` dependency is removed
after feature traffic converged on canonical Dio-backed networking and no Dart
source imports `package:http/http.dart`.

Some compatibility paths are intentionally retained:

- `backend/legacy_snapshot.py` is migration-history infrastructure;
- the deprecated Flutter `ApiClient` is a transport-free compatibility alias;
- the historical `vibematch_app` directory/package path is retained to avoid a
  risky package-rename migration during this roadmap;
- mediasoup Socket.IO is media signaling, not a second application WebSocket;
- room presentation compatibility adapters may remain only while they are
  read-only projections over `RoomSessionRepository`.

Every retained seam has an explicit reason and removal condition. Future cleanup
must update the registry and prove tests/builds/migrations before deletion.
