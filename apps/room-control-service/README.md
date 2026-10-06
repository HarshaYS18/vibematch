# FunKey Room Control Service

Chunk 26 extracts durable room correctness from the core API.

## Owns

Room creation/configuration, membership/admin flags, kickouts, durable seats,
member/seat requests, room chat state, Room State Engine event/version state,
room activities, Watch Party durable state, Room-vs-Room PK challenge/result
state, room themes/reviews/inventory and room moderation actions.

The Go realtime gateway remains transport. Redis remains rebuildable
presence/fanout/replay state. mediasoup remains media transport.

## Cross-domain boundaries

Room Control may read bounded identity/authorization/profile data while the
identity/profile extraction is pending, but it does not write those domains.
Paid room-theme purchases are orchestrated by core: economy performs the
idempotent wallet debit, then this service performs the idempotent room-theme
inventory grant. Contribution rankings remain a core projection and resolve the
room through the authenticated internal API.

## Runtime

- public API: `/api/v1/rooms/**`
- admin API: `/api/v1/admin/rooms/**`
- internal API: `/internal/room-control/**`
- health: `/live`, `/ready`
- metrics: `/metrics`
- port: 8085
- database: `ROOM_CONTROL_DATABASE_URL`


## Internal realtime authority API

`POST /internal/room-control/authorize` resolves authoritative room access and
media permission context. `POST /internal/room-control/command` executes the
allowlisted room command engine inside this deployable. Core realtime and media
code must use these endpoints instead of reading Room Control tables directly.


## Room PK

Room Control owns durable PK challenge, live-score and winner state. The
Economy domain remains authoritative for gifts and wallets; after a gift
settlement commits, core forwards an idempotent score receipt to Room Control.
A scoring projection failure cannot roll back or alter financial settlement.

Public PK operations remain under `/api/v1/rooms/{room}/pk/**`. The internal
`/internal/room-control/pk/gift-score` endpoint is token-protected and exists
only for settled Economy receipts. Realtime `room_pk/state` messages are
transport mirrors of PostgreSQL state, not a second authority.
