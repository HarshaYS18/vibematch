# Final decommissioning and legacy policy

Chunk 56 does not delete code because a filename contains "legacy". A path is
removed only when reachability, compatibility and migration evidence show that
its replacement is authoritative.

Confirmed removals in this chunk are recorded in
`contracts/decommission/decommission-registry-v1.json`. Two concrete dead
paths were decommissioned:

- the obsolete Android `com.example.vibematch_app` activity/service copy after
  the app namespace/applicationId moved to `com.funkey.app`;
- bundled Jungle Hunt game artwork that was not declared by Flutter and conflicts
  with the verified CDN/HTML remote-game architecture.

Some compatibility paths are intentionally retained. The Alembic legacy snapshot
is migration-history infrastructure; the deprecated Flutter `ApiClient` is a
transport-free source-compatibility alias; the historical `vibematch_app`
directory is a repository-path compatibility decision; mediasoup Socket.IO is
media signaling, not a second application WebSocket.

Every retained seam has an explicit reason and removal condition. Future cleanup
must update the registry and prove tests/builds/migrations before deletion.
