# Games / Game Platform

## Purpose

Own game catalog/configuration, durable sessions, round lifecycle, bets, risk
state, game stats and game-domain leaderboards without becoming financial
authority.

## Current deployable

`apps/game-platform-service` is the extracted Chunk 28 authority. Core preserves
stable `/api/v1/games/**` compatibility routes through `game_platform_proxy`.

## Owns

- `game_definitions`
- `game_sessions`
- `game_rounds`
- `game_round_players`
- `game_bets`
- `game_risk_audits`
- `user_game_stats`

## Does not own

Wallets, wallet ledger, coin supply/pool ledgers, game financial pools, final
value settlement, room authority, realtime transport or client UI state.

Economy Service owns all game value movement. A game wager or settlement is an
idempotent Economy command.

## Client/runtime boundary

Gameplay code is remote CDN HTML verified by manifest version, SHA-256 and Host
Bridge compatibility. Remote JavaScript receives no FunKey bearer token and no
database/financial credentials. Flutter's Game Platform runtime is a client
execution sandbox, not durable authority.

## Realtime

Committed lifecycle updates may publish through the canonical application
realtime path. Games do not create another application WebSocket.

## Security

Server-side lifecycle/risk rules, authenticated admin mutation, bundle integrity
and Economy settlement identity are security-critical. Fail closed on unknown
bundle integrity, foreign session/round IDs or ambiguous Economy outcomes.

## Scaling

Scale stateless Game Platform replicas inside the PostgreSQL connection budget.
Remote game byte delivery scales independently through CDN/object storage.

## Operations

See:
- `apps/game-platform-service/README.md`
- `docs/architecture/game-platform-service.md`
- `docs/runbooks/game-platform-service.md`
- `deploy/postgres/game-platform-ownership.sql`

## Migration status

Chunk 28 physical extraction is complete. Core no longer owns Game Platform
mutations. Economy-backed financial facades remain separate and are registered
before Game Platform proxy catch-alls.

## Change checklist

Before changing Games: identify whether the change is gameplay lifecycle or
financial value. Lifecycle belongs here; value belongs in Economy. Preserve
public compatibility, immutable retry context, bundle integrity, observability
and rollback semantics.


## Flutter resource lifecycle

Chunk 34-M7 registers the remote Game Platform WebView through the foundation
`MediaResourceRegistry` port. The Game Platform feature never imports the
concrete AppShell coordinator.

`GameWebViewResourceParticipant` forwards `app.lifecycle` and
`app.memory_pressure` host events to verified remote game HTML. Games may use
those events to pause presentation work or trim reconstructable caches.
Ordinary memory pressure does not reload/destroy an active WebView. Session
teardown releases the runtime, while durable sessions, rounds, bets and Economy
settlement remain backend authority.
