# Backend MVP All Modules v1

Branch: `backend-mvp-all-modules-v1`

Base: `mvp-testable-webrtc-v1`

## Goal

This branch gives FunKey a real FastAPI-backed MVP API surface for the major app modules, without pretending the final production backend is complete.

It adds a persistent generic module state table that lets the frontend stop depending only on local mocks while we later split each feature into dedicated normalized tables and strict permission services.

## New persistent model

```txt
backend/app/models/mvp_feature.py
```

Table:

```txt
mvp_feature_states
```

Stores:

- feature name
- item type
- owner user
- target user
- room public ID
- title
- description
- status
- amount/currency
- JSON payload
- active flag
- created/updated timestamps

## New service layer

```txt
backend/app/services/mvp_feature_service.py
```

Supports:

- list feature items
- create feature item
- get item by public ID
- update item
- deactivate item

## New schemas

```txt
backend/app/schemas/mvp_feature.py
```

Includes:

- `MvpFeatureCreate`
- `MvpFeatureUpdate`
- `MvpFeatureResponse`
- `MvpActionResponse`

## New routes

### Core CRUD

```txt
backend/app/api/routes/mvp_core.py
```

Endpoints:

```txt
GET    /mvp/features
GET    /mvp/{feature}
POST   /mvp/{feature}
GET    /mvp/{feature}/{public_id}
PATCH  /mvp/{feature}/{public_id}
DELETE /mvp/{feature}/{public_id}
```

Supported feature keys:

- wallet
- gifts
- store
- vip
- vibes
- relationships
- family
- agency
- events
- rankings
- watch_party
- cricket_mode
- assets
- reports
- earnings
- control_center

### Social

```txt
backend/app/api/routes/mvp_social.py
```

Endpoints:

```txt
POST /mvp/social/vibes/post
POST /mvp/social/vibes/comment
POST /mvp/social/relationships/request
POST /mvp/social/family/create
POST /mvp/social/family/join-request
```

### Economy

```txt
backend/app/api/routes/mvp_economy.py
```

Endpoints:

```txt
POST /mvp/economy/wallet/recharge
POST /mvp/economy/wallet/transaction
POST /mvp/economy/gifts/send
POST /mvp/economy/gifts/catalog-item
POST /mvp/economy/store/item
POST /mvp/economy/store/inventory
POST /mvp/economy/vip/state
POST /mvp/economy/earnings/payout-request
```

### Operations

```txt
backend/app/api/routes/mvp_operations.py
```

Endpoints:

```txt
POST /mvp/ops/assets/custom-room-background
POST /mvp/ops/events/app-event
POST /mvp/ops/rankings/snapshot
POST /mvp/ops/reports/create
POST /mvp/ops/reports/escalate
POST /mvp/ops/agency/request
POST /mvp/ops/control-center/action
```

### Room Modes

```txt
backend/app/api/routes/mvp_room_modes.py
```

Endpoints:

```txt
POST /mvp/room-modes/watch-party/session
POST /mvp/room-modes/watch-party/sync-event
POST /mvp/room-modes/cricket/session
POST /mvp/room-modes/cricket/score-event
```

## Existing backend kept intact

This branch keeps the existing backend work:

- auth
- users/me
- admin
- moderation
- rooms
- inbox
- inbox websocket route
- mediasoup standalone SFU service from the previous MVP branch

## Important limitation

This is an MVP backend coverage layer. It is not the final production-normalized backend for every FunKey module.

Production work still needed later:

- dedicated normalized tables for each feature
- strict role/permission checks for every sensitive action
- wallet balance locking and ledger accounting
- gift/economy anti-fraud and settlement rules
- final VIP/SVIP recharge logic
- real rankings aggregation jobs
- final Vibes media/comment/mention tables
- final relationship/family/agency membership constraints
- Watch Party realtime websocket sync
- Cricket Mode realtime websocket sync
- asset upload storage/CDN pipeline
- report workflow with evidence files and audit logs
- creator payout review and fraud controls
- Alembic migrations instead of only `create_all`

## Local smoke test

Start FastAPI from `backend` as usual, login with dev login, then call:

```bash
curl http://127.0.0.1:8000/mvp/features \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Create a Vibe post:

```bash
curl -X POST http://127.0.0.1:8000/mvp/social/vibes/post \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"item_type":"post","title":"First backend Vibe","payload":{"caption":"Hello VibeMatch"}}'
```

List stored Vibes:

```bash
curl http://127.0.0.1:8000/mvp/vibes \
  -H "Authorization: Bearer YOUR_TOKEN"
```
