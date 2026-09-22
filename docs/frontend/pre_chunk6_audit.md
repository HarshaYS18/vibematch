# Pre-Chunk-6 architecture audit

Reference head reviewed: `b8189636eacda323cabcf2b07a2bedf94853737d`.

## Resolved before Chunk 6

- Room heartbeat is explicitly a partial snapshot. Sections the server declares omitted are
  preserved by `RoomSessionRepository` instead of being reset.
- Room websocket heartbeat snapshots remain complete replacement snapshots.
- The backend source-of-truth registry now advertises the canonical Chunk 5 room lifecycle
  endpoints and the Flutter client validates that contract.
- Legacy room lifecycle paths are rejected by the Flutter registry validator.
- Missing historical visual/performance evidence is documented without fabrication. The audited
  Chunk 5 head is frozen as the pre-Chunk-6 reference and a strict evidence check now exists.

## Deliberate migration bridges still allowed

These are compatibility adapters, not canonical owners:

- `AuthApiService` retains legacy token/user process caches behind `SessionRepository` and
  `IdentityRepository`.
- `LiveRoomPresenceRepository` and `LiveRoomMembershipService` receive projections from
  `RoomSessionLegacyAdapter` for unmigrated room widgets.
- `LiveRoomMediaSignalingService.roomSnapshot` still feeds legacy seat/media widgets.
  `RoomSessionRepository` remains the canonical room-domain source of truth.
- Existing room presentation controllers remain adapters until the later product migration chunks.

New canonical code must not use these bridges as an authority. The architecture guard already
forbids direct HTTP, static notifier state, direct persistence and direct websocket creation inside
the canonical foundation/session/identity/realtime/room-session roots.

## Chunk 6 entry condition

Chunk 6 may begin only after the normal backend/frontend CI passes on the audit-hardening head.
UI-affecting work must additionally satisfy the strict baseline evidence gate once real captures
have been produced.
