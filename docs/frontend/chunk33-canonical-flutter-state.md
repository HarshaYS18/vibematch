# Chunk 33 — Canonical Flutter State

## Goal

Finish FunKey's Flutter state migration so application/domain state has one
canonical owner and UI widgets consume immutable Riverpod state.

This chunk does **not** redesign the UI. Layout, colors, typography, spacing,
animations and interaction behavior remain visually equivalent.

## Canonical ownership

The allowed ownership model is:

```text
Widget-local ephemeral UI resources
  -> TextEditingController / FocusNode / AnimationController / ScrollController

Application/domain state
  -> Riverpod Provider / Notifier / AsyncNotifier / family / select
  -> immutable state objects

Room durable/client state
  -> RoomSessionRepository
  -> immutable RoomSessionState
  -> Riverpod-derived selectors/view state

Transport/media resources
  -> scoped runtime/services
  -> never a second domain-state authority
```

## State that must not remain authoritative

Chunk 33 removes application-state authority from:

- `ChangeNotifier`
- `StateNotifier`
- static mutable `ValueNotifier`
- process-global mutable feature singletons
- feature event buses that duplicate canonical state
- legacy room caches/adapters that are still writable
- controller-to-controller static routing

Widget-local Flutter controllers are allowed when they are purely UI resources.

## Migration sequence

Every migrated domain follows:

1. **Expand** — introduce immutable Riverpod state/provider.
2. **Mirror** — preserve existing public actions while provider state becomes
   canonical.
3. **Shadow/compare** — retain compatibility reads only while parity is checked.
4. **Freeze old writes** — legacy ChangeNotifier/static cache/event bus may no
   longer mutate canonical state.
5. **Remove old path** — pages consume Riverpod directly.
6. **Guard** — CI rejects reintroduction of forbidden state authority.

No destructive big-bang state migration is allowed.

## Chunk 33 domains

### Core runtime

- Session -> `Notifier<SessionState>`
- Identity -> `Notifier<IdentityState>`
- App shell navigation -> `AutoDisposeNotifier<AppShellNavigationState>`
- App Inbox runtime -> Riverpod runtime state, not ChangeNotifier

### Main/product state

- Home
- Store
- Inventory
- VIP/SVIP center
- Vibes feed
- Vibe detail
- Search
- Banner Manager
- Family
- Inbox
- Inbox calls

Each domain uses immutable state. Provider families are used where page/session
identity must scope state.

### Room state

`RoomSessionRepository` remains the **only canonical room client-state
authority**.

Chunk 33 must remove or de-authorize:

- `LiveRoomStateController` as independent room authority
- `ActiveRoomContext` static mutable room identity
- seat/settings/system static ValueNotifier event buses
- process-global room music state
- static gift/chat controller routing
- writable legacy RoomSession projection caches

Compatibility conversion helpers may remain only when they are pure,
read-only transformations from `RoomSessionState`.

## UI-local state rule

The following may remain local to widgets because they are not business/domain
authority:

- `TextEditingController`
- `FocusNode`
- `AnimationController`
- `ScrollController`
- page-only tab/selection state with no cross-screen authority
- modal/sheet visibility

If local UI state begins to affect another feature or survive route/session
lifecycle, it must move to Riverpod.

## Performance rule

Use provider `select`/derived providers for hot UI surfaces where practical.
Do not rebuild the whole shell or room tree for one unread count, typing flag,
seat, or media-status change.

## Failure/rollback

Rollback is source-compatible because migrations preserve action semantics and
API contracts. A provider migration may be reverted independently if Flutter
tests/analyze/build reveal behavioral drift.

No backend schema, financial authority or public API contract changes are
required for this chunk.

## Observability

Existing Sentry/Flutter error reporting remains active. Provider/runtime
failures must continue to surface through existing repository/API error states;
do not swallow exceptions merely because state ownership moved.

## Acceptance criteria

Chunk 33 is complete only when:

1. no application/domain `ChangeNotifier` remains in feature state;
2. no `StateNotifier`/StateNotifierProvider remains in canonical app state;
3. no static mutable ValueNotifier/event bus is an application-state authority;
4. no feature-level mutable singleton duplicates Riverpod/domain state;
5. Inbox shell/runtime has one Riverpod-backed state authority;
6. RoomSessionRepository remains the sole canonical room state authority;
7. legacy room compatibility writes are removed or read-only pure adapters;
8. an architecture guard blocks new forbidden state authority;
9. regression tests cover provider ownership and room source-of-truth rules;
10. Flutter tests, analyze and production web build pass;
11. existing UI look is unchanged by source architecture work.

## Rollout status

This document is the canonical design record for Chunk 33. Completion status is
updated only after the final architecture guard and CI pass on the final Chunk
33 head.


## Repair-wave documentation rule

Every Chunk 33 implementation file changed by the repair wave must carry
maintainer-facing documentation in the same commit. At minimum, the code must
state its ownership/source-of-truth and lifecycle responsibilities; the
relevant architecture/module document must be updated whenever the ownership
model changes.

### Scoped presentation state completed in this repair wave

- Live-room Cricket presentation is owned by the mounted
  `LiveRoomControllerBundle`; no process-global Cricket notifier is allowed.
- Room chat image/music wiring uses explicit room-scoped controller references.
- Vibes inline action-pill coordination is owned by `VibesPage` and disposed
  with that route. It is intentionally UI-local and is not Riverpod domain
  state.


### Gradient-name ownership

The equipped store gradient is no longer held in a static
`ValueNotifier`. `GradientNameSyncController` is the session-scoped Riverpod
owner, reads through `AppKeyValueStore`, and is invalidated by
`InventoryController` after equip/unequip mutations. Display widgets consume
that provider and fall back safely while it reloads.
