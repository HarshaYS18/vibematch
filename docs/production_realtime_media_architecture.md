# Production Realtime Media Architecture

## Active media path

FunKey uses a control-plane/media-plane split:

1. Flutter joins the application room through FastAPI realtime APIs.
2. Flutter resolves media through `GET /api/v1/rooms/{room_public_id}/media`.
3. FastAPI authorizes access and assigns a healthy media node through Redis.
4. Flutter connects to the returned `signaling_url`.
5. `backend_media` owns mediasoup routers, transports, producers and consumers.
6. Sensitive signaling actions are re-authorized against FastAPI.

FastAPI remains authoritative for authentication, bans, room membership, room state, seats, roles, kicks and application permissions. `backend_media` is authoritative only for media transport state.

## Canonical media implementation

There is exactly one executable media implementation in this repository:

- `backend_media/`

The former `audio-server/`, `media-server/`, and `services/mediasoup-audio-server/` implementations were removed during production consolidation. They must not be restored as parallel signaling services.

TURN infrastructure, when used, lives under `infra/turn/`.

## Media discovery and scaling

Clients must not hard-code a media host or choose a media node directly. FastAPI stores media-node heartbeats, drain state, short-lived capacity reservations and sticky room assignments in Redis.

Draining a node prevents new assignments while allowing already assigned rooms to continue while the node remains healthy. Actual replica creation and termination belongs to the deployment orchestrator.

See [PRODUCTION_RUNBOOK.md](../PRODUCTION_RUNBOOK.md) for startup, health, drain and deployment procedures.

## Room and seat ownership

Room realtime/FastAPI owns seat assignment and application room state. A media socket must not become a second source of truth for seats.

For ordinary room audio, producing audio requires the authoritative room/seat permission checks to pass. Media transport cleanup must not mutate application seat state independently.

## Call media

Inbox calls use server-generated `call_room_*` media namespaces. Only persisted joined call participants can resolve or use those namespaces. Call media uses the same FastAPI discovery and `backend_media` signaling path as room media.

## Reliability invariants

- Joining the same media room is idempotent.
- A peer reuses transport state where appropriate.
- A producer is consumed at most once per peer.
- Producer/consumer/transport state is cleaned on disconnect and leave.
- Media nodes heartbeat into the FastAPI registry and fail readiness when the control-plane registry cannot be maintained.
- Clients re-resolve media through FastAPI rather than relying on a stale node address.
- Production deployments set the mediasoup announced address and RTC port range for the real NAT/network topology.

## Verification

The consolidation CI verifies:

- architecture invariants
- Alembic graph and PostgreSQL migration replay
- backend regression tests
- `backend_media` typecheck, build, lint and lifecycle tests
- Flutter tests and analysis
- Flutter production web build

Manual multi-device RTP/audio validation is still required for each deployment/network environment because NAT, firewall, TURN and browser autoplay behavior cannot be fully proven by repository CI.
