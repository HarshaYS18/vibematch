# FunKey Economy Service

Restored approved Chunk 25 Tier-0 financial authority.

## Owns
Wallet balances, wallet ledger, supply pools/ledgers, gift financial settlement, purchases/refunds value transfer, mission reward credits, and game financial settlement.

## Does not own
Game catalog/round/risk/leaderboards, Store catalog/inventory, Profile/VIP presentation, Room state, or social graph.

## Tier-0 mutation contract
Every new cross-domain financial mutation requires transaction_id, idempotency_key, and business_reference. Completed retries return the stored result. Reusing an idempotency key with different request content, or reusing a transaction ID with another idempotency key, fails closed.

Wallet ledger entries carry the transaction metadata and a durable outbox event is written in the same database transaction.

## Current phase
The service is deployed internal-only first. Public/mobile Economy routes remain on the core API until all non-Economy callers are migrated and database ownership is cut over.

## Operations
/live, /ready, /metrics.
