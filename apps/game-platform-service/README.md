# FunKey Game Platform Service

Chunk 28 deployable for authoritative game catalog/configuration, remote CDN manifest metadata, durable game sessions, rounds/bets, risk metadata, stats and leaderboards.

## Authority boundary

Game Platform owns game-domain lifecycle state only. It never mutates wallet, ledger, coin-supply or house/game-pool financial truth. Wager debit and final payout are idempotent commands to Economy.

Remote game code remains CDN-delivered, SHA-256-verified single-HTML content. The service owns catalog and host contracts, not bundled game UI assets, and remote JavaScript never receives database, wallet or bearer-token credentials.

## Public compatibility

Core keeps stable `/api/v1/games/*` URLs through `game_platform_proxy`. Concrete legacy financial endpoints (`/games/wager`, `/games/settle`, `/games/settle-winnings-to-wallet`) are registered before the Game Platform catch-all and delegate directly to Economy.

The live Flutter Host Bridge opens a durable Game Platform session, binds round creation to that session, and sends retry-stable bet request IDs. The existing visual UI is unchanged.

## Operations

- HTTP: `8089`
- health: `/live`, `/ready`
- metrics: `/metrics`
- database: `GAME_PLATFORM_DATABASE_URL`
- public base: `/api/v1`
- financial authority: Economy service
