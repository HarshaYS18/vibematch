# FunKey Master Source of Truth Architecture

This document defines source-of-truth principles. The enforceable inventory is the
[Architecture Authority Registry](architecture/authority-registry.md) with machine contract
`contracts/architecture/authorities.yaml`.

## Core rule

FunKey must have one master source of truth for the whole app, and only one source of truth for each individual element.

The backend is the master source of truth. Flutter must never be treated as source of truth for permanent app state. Flutter can only hold temporary UI state, optimistic state, animation state, local draft state, or cached snapshots that are replaced by backend truth.

## Master DB rule

FunKey should use one master PostgreSQL database as the backend authority for production data. That does not mean one giant table. It means one canonical backend database owns the truth, and every domain table inside that database has one clear responsibility.

Correct production structure:

```txt
Master PostgreSQL DB
  -> canonical identity tables
  -> child/domain source tables
  -> ledger/event/audit tables
  -> materialized read/snapshot tables or views
  -> backend snapshot APIs and websocket events
```

The `users` table is the root identity table, not the place to dump every changing counter. High-write and history-sensitive data must stay in child tables and ledgers, then be assembled into master snapshots.

## Master user state rule

Every user must have one canonical user identity, and app screens should fetch a clean master user state snapshot assembled from child/domain tables.

Root identity fields belong in `users`:

- backend user ID
- public user ID
- custom display ID
- username
- display name
- avatar URL
- official handle
- basic profile fields
- active/banned/protected flags
- created/updated timestamps

High-change user state belongs in child/domain tables:

- VIP/SVIP status in `user_vip_status`
- wallet balance in `user_wallets`
- wallet/gift/recharge source-of-truth in ledger tables
- sent/received gift totals in contribution/experience tables
- daily/weekly/monthly/yearly aggregates in user stat aggregate tables
- sent level and received level in `user_experience_status`
- current room presence in `room_participants` / room presence tables
- room ownership and room level in room tables / room experience tables
- store inventory in `user_store_inventory`
- relationship/family/CP status in relationship tables
- ranking data in ranking aggregate tables
- moderation/bans in ban tables
- inbox/notification counts in inbox/notification tables

The backend should expose a master snapshot such as:

```txt
GET /users/{user_id}/master-state
GET /users/me/master-state
```

That snapshot can include:

```json
{
  "identity": {
    "backend_user_id": 1,
    "public_user_id": 6922022,
    "display_custom_id": null,
    "username": "founder",
    "display_name": "Maddy 🔥",
    "avatar_url": "..."
  },
  "vip": {
    "vip_level": 25,
    "vip_status": "active",
    "svip_level": 3,
    "svip_expires_at": "..."
  },
  "wallet": {
    "coin_balance": 10000,
    "diamond_balance": 0
  },
  "experience": {
    "sent_level": 16,
    "received_level": 9,
    "sent_exp_lifetime": 123456,
    "received_exp_lifetime": 654321
  },
  "contribution": {
    "sent": {
      "daily": 100,
      "weekly": 500,
      "monthly": 2000,
      "yearly": 12000,
      "lifetime": 50000
    },
    "received": {
      "daily": 80,
      "weekly": 450,
      "monthly": 1800,
      "yearly": 9000,
      "lifetime": 40000
    }
  },
  "room_presence": {
    "current_room_id": "VM251544",
    "room_user_key": "room:VM251544:user:1",
    "is_host": true,
    "is_room_admin": true,
    "seat_index": 0
  },
  "room_stats": {
    "owned_room_id": "VM251544",
    "room_level": 4,
    "room_exp": 900
  }
}
```

This master snapshot is a read model. It can be assembled live from child tables first, then later optimized with a cached/materialized table like `user_master_state_snapshots` or `user_profile_summary`.

## Why not one giant user table

Do not store every changing value directly on `users`. That creates clutter, race conditions, and bad auditability.

Bad pattern:

```txt
users.vip_level
users.coin_balance
users.daily_sent
users.monthly_received
users.current_room_id
users.room_level
users.sent_level
users.received_level
users.gift_total
users.game_total
```

Production pattern:

```txt
users                         -> identity only
user_wallets                  -> current wallet balance
wallet_ledger                 -> every wallet movement
gift_transactions             -> every gift send/receive event
user_contribution_aggregates  -> daily/weekly/monthly/yearly sent/received totals
user_experience_status        -> sent/received levels and EXP
user_vip_status               -> VIP/SVIP state
room_participants             -> current room presence
room_experience_status        -> room level/EXP
user_master_state_snapshots   -> optional cached read model assembled from child tables
```

The app should fetch the final clean snapshot. The backend should fetch/compute it from the child tables.

## App-wide source-of-truth flow

```txt
User action in Flutter
  -> backend command endpoint or websocket command
  -> backend authenticates user
  -> backend loads current DB state
  -> backend checks permission and hierarchy
  -> backend writes canonical state in DB transaction
  -> backend writes event/audit/ledger row when needed
  -> backend updates aggregate/read model when needed
  -> backend commits
  -> backend publishes realtime event
  -> all clients update from event or refetch snapshot
```

## Golden rules

1. No duplicated owners for the same state.
2. No permanent state lives only in Flutter.
3. No permanent state lives only in WebSocket memory.
4. No wallet/economy value is calculated on the client.
5. No admin/owner/room permission is trusted from the client.
6. Every screen loads an initial backend snapshot.
7. Every realtime event either updates that snapshot or triggers a refetch.
8. Every sensitive change is audit/event logged.
9. Every money/coin/gift/game action is ledger-based.
10. Every domain must define its canonical table/service/event owner.
11. Every real room event must be broadcast through backend realtime to all eligible room users.
12. No room event should be local-only unless it is purely private UI state such as an input draft, scroll position, or animation progress.
13. User identity belongs in `users`; changing stats/counters belong in child tables, ledgers, and aggregate/read models.
14. Flutter should fetch user master state snapshots, not stitch important profile/economy/rank data from local state.

## Bigo-style broadcast rule

Every meaningful in-room action must flow through backend and broadcast to all eligible users, Bigo-style. The client may animate instantly, but the authoritative event must still come from the backend or be confirmed by a backend snapshot.

Room events that must never be local-only include:

- user joined room
- user left room
- seat taken
- seat left
- seat switched
- seat locked/unlocked
- mic self mute/unmute
- admin mute/unmute
- room admin add/remove
- room settings changed
- room mode changed
- background/theme changed
- chat text/image message sent
- floating/ribbon message sent
- gift sent
- combo gift updated
- lucky gift result
- lucky packet sent/claimed
- global/regional broadcast created
- room announcement changed
- join request submitted/approved/rejected
- room member/admin/kick/mute moderation action
- cricket mode start/update/end
- watch party start/update/end
- games round start/bet/result/end
- wallet/level/contribution updates caused by room actions

The only local-only state allowed in room UI is temporary private interface state:

- text currently typed but not sent
- selected gift before pressing send
- open/closed bottom sheet
- scroll position
- local animation progress
- selected tab/filter
- drag position of minimized bubble
- temporary loading indicators

If another user in the same eligible room should see or be affected by the action, it is not local state. It must be backend-saved or backend-validated, then broadcast.

## Canonical authority registry

The historical inline table was retired in Chunk 15 because it duplicated module documentation and had become stale for implemented features such as Watch Party.

Use, in order:

1. `contracts/architecture/authorities.yaml` — machine-readable ownership/classification contract enforced by CI.
2. `docs/architecture/authority-registry.md` — human ownership summary.
3. `docs/architecture/state-classification.md` — state semantics.
4. `docs/architecture/service-boundaries.md` — logical owner versus current deployable.
5. `/api/v1/app/source-of-truth/master` — client screen delivery registry, not a competing architecture authority.

A module README that conflicts with the machine registry is architecture drift and must be corrected before merge.

## Client state categories

Flutter may store these temporarily:

- selected tab/page
- scroll position
- animation progress
- local input drafts
- selected gift before sending
- temporary bottom-sheet state
- cached images/assets
- optimistic UI only when rollback/refetch is supported

Flutter must not own these permanently:

- room participants
- seats
- locks
- mic/admin mute
- wallet balance
- gifts sent/received
- rankings
- VIP/SVIP level
- room mode/privacy
- room settings
- relationship state
- bans/permissions
- inbox messages
- Vibes posts/comments/reactions

## Backend domain ownership pattern

Each domain should follow this file pattern:

```txt
models/<domain>.py             # database source-of-truth tables
schemas/<domain>.py            # request/response contracts
services/<domain>_service.py   # write logic and transactions
services/<domain>_snapshot.py  # read/snapshot logic when large enough
api/routes/<domain>.py         # thin routes only
realtime/events.py             # event contract names
```

Routes must not contain business rules. Routes call services. Services own writes. Snapshot services own reads.

## Snapshot + event contract

Every realtime feature must support both:

1. snapshot fetch: latest full backend truth for that screen/module
2. realtime event stream: incremental updates after snapshot

If the client misses events, it refetches the snapshot.

## Versioning rule

Every important snapshot should include a monotonic version or event sequence.

For rooms this is now `state_version` from `room_realtime_events.sequence`.

Later each domain should expose similar versions:

- `room.state_version`
- `wallet.ledger_version`
- `inbox.last_message_id`
- `profile.updated_at`
- `vibes.cursor/version`
- `user_master_state.version`

## Conflict rule

If Flutter cache and backend snapshot disagree, backend wins.

If WebSocket event and REST snapshot disagree, latest backend snapshot wins.

If two backend services appear to own the same field, that is a bug. Move ownership to one service.

## Bigo-style room stability rule

A chatroom should survive:

- minimize/restore
- app background/foreground
- socket reconnect
- browser refresh
- leaving room screen and coming back
- backend worker restart after reconnect/refetch

Therefore room seats, room settings, mic state, locks, chat history, gifts, room mode, and presence must be restorable from backend snapshot. WebSocket memory is delivery-only, not state ownership.

## Current implementation status on this branch

Implemented foundation:

- persistent room seats: `room_seat_states`
- persistent room events: `room_realtime_events`
- persistent room chat messages: `room_chat_messages`
- canonical room participant identity snapshot fields in backend room snapshots
- room state snapshot service
- room action service
- room permission service foundation
- websocket route backed by DB/service snapshots
- REST command router for room realtime actions
- raw socket disconnect does not mutate saved room state

Still needed:

- token-auth command endpoints instead of temporary `user_id` in body
- Redis pub/sub implementation behind `RealtimeEventBus`
- full audit logging for every room action
- frontend repository wiring to always load snapshots first
- event replay/offline delivery
- implement `user_master_state_service` and master-state endpoints
- create aggregate/read models for contribution totals, VIP/SVIP, levels, room state, wallet summary
- same source-of-truth registry applied to wallet, gifts, inbox, Vibes, profile, store, games, cricket, watch party
- convert remaining local-only room UI actions into backend command + broadcast + snapshot-confirmed actions
