# FunKey production runbook

This is the operational entry point for the current FunKey architecture through
Chunk 32 and the post-audit repair pass. The machine authority registry is
`contracts/architecture/authorities.yaml`; provider/account prerequisites remain
in `docs/EXTERNAL_PREREQUISITES.md`.

## Runtime topology

| Workload | Port | Responsibility |
|---|---:|---|
| Core FastAPI | 8000 | stable public compatibility/composite reads and remaining non-extracted domains |
| Go realtime gateway | 8081 | single `funkey.v2` application WebSocket, routing, presence/replay |
| Worker Platform | 8082 | specialized JetStream execution pools, retry/backpressure/DLQ |
| Inbox Service | 8083 | Inbox durable authority |
| Vibes Service | 8084 | Vibes/feed durable authority |
| Room Control Service | 8085 | room/membership/seat/watch/activity authority |
| Identity Service | 8086 | account/auth/session/device authority |
| Profile/Social Service | 8087 | profile/social/family membership authority |
| Economy Service | 8088 | exclusive Tier-0 financial writer |
| Game Platform Service | 8089 | game lifecycle/risk/stats; no financial authority |
| Notification Service | 8090 | notification/device/preference/delivery authority |
| Notification provider worker | 8091 health | FCM provider delivery only |
| `backend_media` | 4100 | mediasoup signaling/SFU transport |

Economy bulk workers use the Economy image and isolated Economy credentials.
They also run bounded read-only ledger/journal reconciliation. Media upload/
processing work is handled by the media worker pool.

## Authority invariants

- PostgreSQL is durable business truth.
- Extracted services are the only mutation owners for their domain tables.
- Economy Service is the only financial writer; core may have Economy SELECT-only access.
- Go realtime is transport/routing/presence/replay only.
- Redis/Valkey is cache/ephemeral/projection only.
- NATS JetStream carries operational async work from transactional outbox events.
- `backend_media` owns WebRTC transport, never room authorization/business truth.
- object storage/CDN owns bytes, not media/game business state.
- Flutter caches are replaceable client state.
- Alembic is the only production schema mutation path.

## Realtime authentication

The Go gateway validates short-lived signed realtime capabilities locally.
Connect grants and room-specific subscribe grants are distinct. Durable commands
are relayed to their owning authority. Do not restore periodic hot-path auth
round trips or legacy FastAPI application WebSocket authorities.

## Required infrastructure

Production requires managed PostgreSQL with PgBouncer and direct migration DSN,
three isolated Redis/Valkey roles, NATS JetStream, private object storage/CDN,
TURN, Kubernetes, TLS/DNS, secret management/workload identity, registry,
observability backends and tested backup/PITR. Provider-specific activation is
tracked in `docs/EXTERNAL_PREREQUISITES.md`.

## Database ownership

Apply Alembic first, then the relevant ownership SQL for extracted domains.
Core should receive reader roles only where a documented composite read still
needs direct SQL.

For Economy, apply `deploy/postgres/economy-ownership.sql`; never grant
`funkey_economy_runtime` to core or another service. Reconciliation mismatches
must be investigated from ledger/transaction/journal evidence, not repaired by
editing balances.

## Production boot order

1. Managed PostgreSQL/PgBouncer, Redis roles, NATS, object storage/CDN and TURN are healthy.
2. Kubernetes nodes, ingress, DNS/TLS, secret injection and observability are healthy.
3. Run the Alembic PreSync migration job to the expected head.
4. Apply/verify domain ownership roles.
5. Start Identity and Profile/Social.
6. Start Economy and its bulk/reconciliation workers.
7. Start Inbox, Vibes, Room Control, Game Platform and Notification/provider workers.
8. Start core compatibility API and confirm owner dependencies/readers.
9. Start Go realtime and verify capability key retrieval, Redis and room replay.
10. Start general/specialized worker pools and verify JetStream consumers/DLQs.
11. Start media nodes and verify registry heartbeat, assignment and TURN.
12. Promote client traffic only after smoke, dashboards and rollback checks pass.

## Health and deployment checks

Every service must pass `/live`, `/ready` and metrics checks appropriate to its
runtime. A healthy core API does not imply Inbox/Economy/Room/Notification
health; check the owning service for the failing capability.

Production images are immutable digest pins. Staging may auto prune/self-heal;
production promotion requires reviewed GitOps sync. Do not auto-downgrade schema
during application rollback.

## Scaling and drain

- Domain APIs scale within their isolated PostgreSQL connection budgets.
- Go realtime scales on connection/in-flight pressure and drains before termination.
- Worker pools scale independently by consumer lag and bounded concurrency.
- Economy bulk-worker scale must remain inside its dedicated DB budget.
- Media scale-in drains nodes before termination and assignment removal.
- Notification provider workers scale delivery independently of the public API.

## Economy incident checks

Monitor:
- transaction error/idempotency conflicts
- wallet/DB pool latency
- outbox backlog
- bulk job failures
- `funkey_economy_reconciliation_wallet_mismatches`
- `funkey_economy_reconciliation_supply_pool_mismatches`
- `funkey_economy_reconciliation_game_pool_mismatches`
- `funkey_economy_reconciliation_reservation_mismatches`
- `funkey_economy_reconciliation_unbalanced_journals`

Any non-zero reconciliation mismatch is an incident. Do not dual-write from core
as a workaround.

## Inbox incident checks

Conversation lists are summary-only. Active message history is independently
cursor-paged. If Inbox list latency grows, inspect conversation query plans and
last-message summary query; do not reintroduce embedded full histories.

## Media v2

Upload sessions authorize direct object-store upload. Completion verifies object
metadata before durable processing begins. Processing/moderation/cleanup occur
through worker events. Never fix CDN access by making user media public-read.

## CI / pre-deploy gates

The branch must pass:
- backend architecture/authority guards
- fresh and legacy Alembic replay
- backend regressions and PostgreSQL query plans
- service contracts and generated clients
- Go format/vet/test/race
- media typecheck/build/lint/tests
- Flutter tests/analyze/production web build
- Terraform/Kustomize/Compose validation
- container builds and vulnerability scan
- secret/source scan and SBOM
- load/chaos harness parse checks

Repository CI is not real-environment capacity proof. Staging still needs
provider binding, restore drills, TURN tests, distributed load/soak, failure
drills, alert delivery and rollback evidence.

## Runbooks

Use `docs/runbooks/README.md` plus domain-specific runbooks, especially Economy,
Inbox, Room Control, Notification, Worker Platform, Media v2 and realtime.
