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


### Love Bond ownership

Love Bond request/inventory client state is now owned by
`loveBondRealtimeProvider` as immutable `LoveBondRealtimeState`. Backend APIs
remain authoritative. Public-profile presentation watches the provider and
pure card-mapping helpers receive explicit request snapshots; no static
`ValueNotifier` relationship cache remains.


### Gift presentation ownership

Flying-gift and premium-broadcast queues are owned by the room-scoped
`LiveRoomGiftController`. `LiveRoomGiftOverlay` receives those queue objects
explicitly. The queues contain animation-only state, preserve authoritative
backend/local dedupe, and are disposed on room exit; no process-global gift
presentation `ValueNotifier` remains.


### Source-documentation backfill — room composition

The repair wave now documents ownership/lifecycle directly in
`live_room_message_controller.dart`, `live_room_layout_module.dart`,
`live_room_settings_module.dart`, `live_room_input_dock.dart`, and
`live_room_settings_sheet_module.dart`. These files are presentation/scoped
coordination layers only; RoomSessionRepository and backend/realtime services
remain canonical authorities.


### Source-documentation backfill — room controllers and Cricket

Ownership/lifecycle documentation is also embedded in
`live_room_seat_controller.dart`, `live_room_controller_bundle.dart`,
`cricket/live_room_cricket_module.dart`, `cricket_mode_module.dart`,
`cricket_stumps_flow_module.dart`, and
`cricket_stumps_flow_safe_module.dart`. Cricket mutable runtime is
room/widget-scoped; canonical room and backend cricket state remain external
authorities.


### Love Bond consumer migration

Inbox, signed-in profile synchronization, public-profile synchronization, and
relationship panels now access `loveBondRealtimeProvider` through their
Riverpod scope. No compatibility callsite restores the retired static
`LoveBondRealtimeService`; consumers either read immutable provider state or
invoke the provider notifier for backend synchronization/actions.


### Gift regression-test ownership

Gift broadcast/combo regression tests now create and dispose their own
`GiftFlightBus`/`PremiumGiftBroadcastBus` instances. Tests therefore verify
the same room-scoped lifecycle as production and cannot rely on or accidentally
reintroduce process-global reset hooks.


## Canonical room chat repair

The final Chunk 33 anomaly audit found that image upload UI and durable chat
state had diverged. The repaired ownership model is now:

```text
RoomInputDock upload
  -> LiveRoomMessageController.sendImageMessage (awaited)
  -> RoomSessionRepository.sendChatMessage
  -> POST /rooms/{room}/realtime/chat/send
  -> PostgreSQL room_chat_messages
  -> canonical recent_messages snapshot/delta
  -> RoomSessionLegacyAdapter.toChatEntries
  -> scoped LiveRoomMessageController presentation list
```

Image chat stores `message_type=image`, `media_url`, and optional
`content_type`; no placeholder text is required. The success toast is emitted
only after the canonical command completes.

The old top-level `roomChatClearSignal` was removed. Chat clear is represented
by canonical `recent_messages` becoming empty, so one room can no longer clear
another room's presentation through process-global Flutter state.

The architecture guard now rejects top-level
`ValueNotifier`/`ChangeNotifier` state as well as static notifier state.
Regression coverage verifies text/image projection order and image metadata.


### Micro-chunk 33-M2 — awaited Flutter image-send path

Flutter image sending is now protected by focused regression coverage. The
room-scoped `LiveRoomMessageController` awaits
`RoomSessionRepository.sendChatMessage(messageType: 'image', ...)`, and the
input dock awaits that controller future before showing the success toast.

`room_session_repository_test.dart` verifies the exact canonical
`/realtime/chat/send` request body and reconciliation of the returned image
message. `room_session_source_of_truth_test.dart` guards the awaited
controller/dock chain and prevents a regression to singleton/local-only chat
sending. No UI styling or interaction layout changes are part of this
micro-chunk.


### Micro-chunk 33-M3 — authoritative canonical chat projection

Canonical room chat projection now has an explicit snapshot-readiness boundary.
The repository's initial `idle`/`joining` state is not treated as an
authoritative chat snapshot, so it cannot erase route-restored messages while a
room is joining. Once the repository reaches an authoritative
`connected`/`reconnecting` (or terminal snapshot-carrying
`leaving`/`left`) state, `recent_messages` fully replaces durable chat
presentation through `RoomSessionLegacyAdapter.toChatEntries`.

The adapter also normalizes an empty backend `message_type` to text and the
regression suite verifies startup preservation, connected replacement,
text/image ordering, metadata projection, and repeated identical canonical
messages. No UI appearance changes are introduced.


### Micro-chunk 33-M4 — room-scoped canonical chat clearing

Chat clearing now has one mutation path:
`LiveRoomSettingsModule -> RoomSessionRepository.clearChat() ->
POST /rooms/{room}/realtime/chat/clear -> backend room/chat_clear ->
canonical recent_messages`.

The settings action awaits the canonical command and reports success only after
the reconciled snapshot returns. The legacy
`LiveRoomMediaSignalingService.broadcastChatCleared()` transport command and
`LiveRoomMessageController.clearChatForEveryone()` local-list mutation were
removed, so neither the media singleton nor a presentation controller can act
as an alternate durable-chat authority.

Regression coverage verifies the backend REST route, the exact repository
request/reconciliation behavior, and source-level absence of the retired
global/local clear paths. No room UI styling or layout changed.


### Micro-chunk 33-M5 — top-level mutable Flutter state guard completion

The whole-app architecture guard already rejects both static and top-level
`ValueNotifier`/`ChangeNotifier` authorities. M5 resolved the final
violations it exposed instead of adding an allowlist.

- `room_theme.dart` no longer stores the selected background in
  `activeRoomBackgroundTheme`; selection flows through the owning room state
  and explicit picker callback.
- `room_seats.dart` no longer uses `roomSeatActionDismissSignal`. Seat-menu
  overlays are widget-local, while cross-widget dismissal is routed through
  the mounted room's `LiveRoomSeatController.clearSelectedSeat()`.
- `RoomInputDock`, `LiveRoomBody`, and `LiveRoomLayoutModule` pass that
  scoped callback explicitly.
- Source-of-truth regression coverage prevents either retired global from being
  reintroduced.

The guard has no exception for these files. UI appearance and interaction
layout remain unchanged.


### Micro-chunk 33-M6 — final anomaly and ownership closure

The final audit removed the last durable mutations that still bypassed
canonical room ownership:

- text chat now awaits `RoomSessionRepository.sendChatMessage(text: ...)`,
  matching the already-canonical image-chat path;
- the message composer is cleared only after that canonical command succeeds;
- room-images, guest-messages and apply-only settings are persisted through
  `RoomSettingsRepository.updateAccessSettings`, reconciled into
  `RoomSessionRepository`, and broadcast once by the backend;
- duplicate media-singleton settings commands for image/guest/apply,
  background and announcement were removed;
- the media facade no longer exposes `sendRoomChat`;
- the obsolete `ActiveRoomContext` facade and no-op
  `RoomSeatLayoutSyncService` were deleted;
- architecture/source guards now prevent those retired authorities from
  returning.

`LiveRoomMediaSignalingService` remains only as a compatibility/media runtime
for audio, transient room effects, invitations and derived media projection.
It does not own durable chat or settings mutations. Canonical durable room
state continues to live in `RoomSessionRepository`.

Regression coverage now protects canonical text chat, image chat, chat clear,
settings ownership, scoped room UI coordination, canonical chat projection and
the absence of retired compatibility files.

#### Final Chunk 33 implementation status

All planned Chunk 33 state-ownership repairs are implemented. Completion is
considered verified only when the final branch-head architecture guard,
backend/service contracts, Flutter tests/analyze and production-platform
checks pass. No UI visual redesign was introduced by Chunk 33.


### Post-M6 repair R1 — stale active-room context removal

The M6 deletion of `ActiveRoomContext` exposed callers that had not yet been
migrated. R1 completes that migration without restoring a process-global room
identity cache:

- privacy and contribution-ranking sheets now require/use the explicit room id
  supplied by the room controller bundle;
- gift controllers receive the room id from `LiveRoomControllerBundle` and use
  it only as command context for backend gift/relationship requests;
- gift and lucky-win realtime overlays receive the mounted room id from
  `LiveRoomOverlayHost` and filter events against that scope;
- session cleanup no longer clears a deleted global room cache;
- Room Level accepts an explicit room id and uses the attached media room only
  as a transient navigation fallback, never as durable state authority.

Ownership remains unchanged: PostgreSQL/backend commands are durable authority,
`RoomSessionRepository` is canonical room client state, and media transport owns
only transient attachment/media lifecycle.


### Post-M6 repair R2 — scoped seat-action dismissal

M5 intentionally removed the process-global seat-action dismissal signal when
`RoomSeatLayout` became widget-local. R2 removes the stale callers of the
deleted `dismissRoomSeatActionPill()` helper:

- layout/lifecycle/overlay actions clear the mounted room's
  `LiveRoomSeatController.selectedSeatIndex`;
- the input dock threads that scoped callback into the message composer;
- the message composer no longer imports the seat widget just to invoke global
  presentation state.

Seat-menu lifetime is now controlled entirely by room-scoped seat selection and
the mounted `RoomSeatLayout` overlay entry.


### Post-M6 repair R3 — background command ownership

R3 removes the remaining media-facade background-setting calls. Cricket restore
and both background pickers already invoke
`LiveRoomStateController.setSelectedBackgroundTheme`, whose canonical command
persists the selected theme through `RoomSettingsRepository.updateBackground`
and reconciles the returned settings snapshot. The redundant media command has
been deleted.

The media facade continues to carry transient Cricket Mode start/end signaling,
but it no longer originates durable room-background mutations.
