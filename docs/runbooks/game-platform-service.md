# Game Platform Service Runbook

## Invariant

Game Platform owns gameplay lifecycle; Economy owns money/value. Never repair a
game incident by directly editing wallet, ledger or game financial pool tables.

## First checks

1. `/ready` and Game Platform DB pool.
2. core compatibility proxy reachability.
3. game catalog/manifest version and CDN availability.
4. durable session/round/bet state.
5. Economy service health for wager/settlement failures.
6. outbox/realtime event delivery after committed state.

## Remote bundle failures

If a bundle fails SHA-256/version/bridge validation, fail closed and mark the
game unavailable. Do not bypass integrity validation or restore bundled gameplay.
Publish a corrected immutable bundle/manifest and update the authoritative
catalog configuration.

## Retry/idempotency

Use the original durable game session/round/bet identity on retry. Financial
retry context must remain immutable and must reuse the original Economy
business reference/idempotency identity.

## Economy outage

Do not mark a wager or settlement financially complete if Economy outcome is
unknown. Reconcile using the original Economy mutation identity before retrying.

## Database ownership

`deploy/postgres/game-platform-ownership.sql` gives mutation rights only to the
Game Platform runtime for lifecycle tables. Economy financial tables are excluded.

## Rollback

Roll back to a schema-compatible Game Platform image while preserving current
table ownership. Core remains a compatibility proxy, not a restored writer.
