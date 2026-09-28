# Game Platform Service architecture

## Status

Chunk 28 is extracted and live in repository architecture as
`game-platform-service`. Core retains stable compatibility URLs only.

## Authority

Game Platform owns game-domain lifecycle state:

- game definitions/catalog configuration
- durable game sessions
- rounds and round participants
- bets and immutable retry context
- risk/audit state
- user game stats and game-domain leaderboards

Game Platform does **not** own wallets, wallet ledger, coin supply, game financial
pools/ledger or final settlement. All value movement is an idempotent Economy
command.

## Runtime

- service port: `8089`
- health: `/live`, `/ready`
- metrics: `/metrics`
- database: `GAME_PLATFORM_DATABASE_URL`
- DB ownership: `deploy/postgres/game-platform-ownership.sql`

Core preserves `/api/v1/games/**` and admin compatibility paths through
`game_platform_proxy`. Economy-backed concrete financial routes are registered
before the Game Platform catch-all.

## Remote game runtime

Flutter loads signed/verified remote HTML gameplay bundles through the canonical
Game Platform runtime. CDN/object storage carries executable bytes; PostgreSQL
catalog/session/round state remains authority. Remote JavaScript receives only
the narrow Host Bridge contract and never receives bearer tokens or DB/financial
credentials.

## Economy boundary

Every wager/final settlement crosses `economy_service_client` with stable
business identity. A Game Platform retry cannot silently generate a different
financial operation. Game Platform must not write Economy tables as a fallback.

## Realtime

Game lifecycle events may fan out through the canonical application realtime
path after authoritative commit. The game runtime does not create another app
WebSocket authority.

## Rollback

Keep Game Platform lifecycle ownership and Economy financial ownership separate
through rollback. Do not restore direct core game-table writers or bundled
Flutter gameplay as an emergency shortcut.
