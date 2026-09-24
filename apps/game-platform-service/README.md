# FunKey Game Platform Service

Chunk 28 deployable for authoritative game catalog/configuration, remote CDN manifest metadata, game sessions, rounds/bets, risk metadata and leaderboards.

Game Platform owns game-domain state only. It must never mutate wallet, ledger, coin-supply or game-pool financial truth. Coin debits and final payouts are commands to Economy. Remote game code remains CDN-delivered verified single-HTML content; the service owns metadata and host contracts, not bundled game UI assets.

The foundation mounts the canonical game surfaces on an isolated runtime. Core traffic is switched only after the live /games/rounds/{roundId}/bets and /settle-test financial paths delegate to Economy.

Operations: HTTP 8089; health /live and /ready; metrics /metrics; database GAME_PLATFORM_DATABASE_URL; public base /api/v1.
