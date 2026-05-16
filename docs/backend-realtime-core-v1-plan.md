# Backend Realtime Core Rework Plan

Branch: `backend-realtime-core-v1`
Base copied from: `beta-release-ready`

## Goal

Keep the current Flutter UI visually intact while rebuilding the backend into a clean, realtime-first system where every important app state is:

1. saved in PostgreSQL,
2. cached or coordinated through Redis where needed,
3. broadcast through WebSocket events,
4. fetched through clean REST snapshots on screen load/reconnect,
5. permission-checked and audit-logged on the backend.

The target behavior is Bigo-style data flow: UI reads server truth, actions go to backend, backend validates and saves, backend emits realtime updates, all clients update instantly.

## Hard rules for this branch

- Do not redesign Flutter UI.
- Do not change current visual layouts unless a backend contract requires a tiny wiring change.
- Remove fake/local-only app state step by step only after equivalent backend state exists.
- No decorative/dead UI buttons: every visible action must call backend, WebSocket, or a mapped safe placeholder.
- Never trust client-side role flags, room admin flags, seat ownership, mute state, wallet values, room mode, or privacy state.
- Secret Vibe and hidden-presence rules must be enforced backend-side before broadcasting anything.

## Current backend problem snapshot

The current backend has many route files and MVP endpoints, but the realtime/data ownership is scattered. Some WebSocket routes currently keep live room state in process memory. That works for local testing but not for real beta release because state disappears on backend restart and cannot scale across multiple workers/servers.

Examples to replace with a clean core:

- room realtime peer/seat state should not live only in module-level dictionaries.
- seat lock/take/leave, mic, admin mute, room settings, room mode, theme, watch party, cricket mode, ribbon chat, gift events, and global broadcasts need persistent event/state flow.
- inbox WebSocket already has token auth, but delivery/typing/read events need a consistent event bus pattern shared with rooms and notifications.

## New backend structure target

```txt
backend/app/
  api/routes/
    realtime.py                  # global authenticated WebSocket entrypoint
    rooms.py                     # room REST snapshots/actions only
    inbox.py                     # inbox REST snapshots/actions only
    wallet.py                    # wallet REST only
    gifts.py                     # gift REST actions only

  realtime/
    connection_manager.py         # per-user/per-room socket registry
    event_bus.py                  # Redis pub/sub abstraction
    events.py                    # typed realtime event names/payload contracts
    auth.py                      # token auth for WebSocket connections
    permissions.py               # realtime permission gates
    serializers.py               # converts DB models to client event payloads

  services/
    rooms/
      room_state_service.py       # source-of-truth room state snapshots
      room_action_service.py      # join/leave/seat/mute/settings actions
      room_event_service.py       # persist event + publish realtime event
      room_permission_service.py  # hierarchy + Secret Vibe + room admin rules
    inbox/
      inbox_action_service.py
      inbox_event_service.py
    economy/
      wallet_service.py
      gift_service.py
      transaction_service.py
    audit/
      audit_service.py
```

## Event flow pattern

Every important action should follow this same pipeline:

```txt
Flutter action
  -> REST command or WebSocket command
  -> authenticate user
  -> load server state from DB
  -> permission check
  -> transaction begins
  -> write DB state/event/audit logs
  -> transaction commits
  -> publish event to Redis/event bus
  -> WebSocket manager broadcasts to eligible clients
  -> Flutter updates UI from event
```

Reconnect pattern:

```txt
Flutter screen opens/reconnects
  -> REST snapshot fetch
  -> WebSocket subscribe/join channel
  -> server sends latest snapshot/version
  -> future changes arrive as events
```

## Core event names

### Room events

- `room.snapshot`
- `room.joined`
- `room.left`
- `room.member_count.updated`
- `room.settings.updated`
- `room.mode.updated`
- `room.theme.updated`
- `room.lock.updated`
- `room.secret_vibe.updated`

### Seat and mic events

- `seat.taken`
- `seat.left`
- `seat.switched`
- `seat.locked`
- `seat.unlocked`
- `seat.admin_assigned`
- `mic.self_muted`
- `mic.self_unmuted`
- `mic.admin_muted`
- `mic.admin_unmuted`

### Chat/gift/economy events

- `room.chat.message_created`
- `room.chat.image_created`
- `room.ribbon.created`
- `gift.sent`
- `gift.combo.updated`
- `wallet.balance.updated`
- `level.sender.updated`
- `level.receiver.updated`
- `room.level.updated`
- `global.broadcast.created`

### Feature-mode events

- `watch_party.started`
- `watch_party.updated`
- `watch_party.ended`
- `cricket_mode.started`
- `cricket_score.updated`
- `cricket_mode.ended`

### Inbox/notification events

- `inbox.message_created`
- `inbox.invite_created`
- `inbox.typing.started`
- `inbox.typing.stopped`
- `inbox.read.updated`
- `notification.created`

## Database source-of-truth tables needed

Existing tables should be reused where clean. Missing or weak areas should be added with Alembic migrations.

Minimum beta-ready room realtime state:

- `rooms`
- `room_memberships`
- `room_admins`
- `room_participants` / `user_room_presence`
- `room_seats`
- `room_seat_locks`
- `room_mic_states`
- `room_settings`
- `room_events`
- `room_chat_messages`
- `room_invites`
- `room_audit_logs`

Minimum beta-ready economy/realtime state:

- `wallets`
- `wallet_ledger`
- `gift_catalog`
- `gift_transactions`
- `gift_combo_sessions`
- `room_contribution_ledger`
- `user_experience_status`
- `room_experience_status`

Minimum beta-ready inbox/notification state:

- `inbox_conversations`
- `inbox_participants`
- `inbox_messages`
- `user_notifications`
- `notification_delivery_state`

## First implementation milestones

### Milestone 1: backend cleanup foundation

- Create `app/realtime/` package.
- Move generic WebSocket connection logic out of route files.
- Add typed event constants/contracts.
- Add Redis-backed event bus abstraction with local fallback for dev.
- Keep old endpoints temporarily, but stop adding new logic to scattered route files.

### Milestone 2: room state source of truth

- Create `room_state_service.py` to return one full room snapshot.
- Create `room_action_service.py` for join/leave/take seat/leave seat/lock seat/mute/settings.
- Persist seat state and mic state in DB.
- Emit WebSocket events only after DB commit.
- Replace module-level `_room_state`, `_room_clients`, and `_peer_room` dictionaries in the room route.

### Milestone 3: presence and privacy

- Make room presence backend-only and permission-filtered.
- Secret Vibe rooms must never broadcast public discoverability or public user-room presence.
- Hidden presence for Founder/Owner must not leak through online lists, mini profiles, room lists, or broadcasts.

### Milestone 4: inbox and notifications

- Convert inbox message send/read/typing into the same event bus.
- Persist every message/invite/read state before broadcast.
- Add notification delivery state so offline users receive pending events after reconnect.

### Milestone 5: gifts/wallet/ribbon/global broadcast

- Gift send action must be a DB transaction: wallet debit, gift transaction, receiver contribution, sender/receiver EXP, room contribution, broadcast event.
- Ribbon chat must debit coins, persist message, then broadcast.
- Global broadcasts must check privacy before publish.

### Milestone 6: frontend wiring without UI redesign

- Keep current widgets and layout.
- Replace local mock data providers with repository classes calling REST snapshots and WebSocket streams.
- Home, Live Room, Inbox, Vibes, Me/Public Profile should all load server snapshots first, then subscribe to realtime updates.

## Backend anti-clutter rules

- Routes should be thin: parse input, call service, return response.
- Services own business logic.
- Permission checks must be central, not duplicated in UI or routes.
- DB writes must happen in one transaction for each user action.
- WebSocket broadcasts must happen after successful commit.
- Every sensitive action must create audit logs.
- No `.backup_YYYY...` Python files should remain active in app packages.
- No static uploaded user media should be committed into git long-term; move to storage/CDN later.

## Immediate next coding task

Start with Milestone 1 and 2:

1. Add `backend/app/realtime/events.py`.
2. Add `backend/app/realtime/connection_manager.py`.
3. Add `backend/app/realtime/event_bus.py`.
4. Add `backend/app/services/rooms/room_state_service.py`.
5. Add `backend/app/services/rooms/room_action_service.py`.
6. Replace the in-memory room WebSocket route with service-backed snapshot + event publishing.
7. Run backend import check and Flutter analyze without changing UI.
