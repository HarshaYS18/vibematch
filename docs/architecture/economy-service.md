# Economy Service architecture

## Status

Chunk 25 authority cutover is complete after the post-Chunk-32 architecture
repair. Economy Service is the sole durable financial writer.

## Boundary

Economy owns value movement. It does not own game lifecycle, room membership,
identity, profile/social state, realtime transport, or client state.

Core may expose stable public URLs and compose read models, but core receives a
SELECT-only Economy database role. All financial mutations use authenticated
Economy APIs with stable mutation identity.

## Durable state

Primary financial state:

- `user_wallets`
- `wallet_ledger`
- `coin_supply_pools`
- `coin_pool_ledger`
- `game_pools`
- `game_pool_ledger`
- `coin_sale_orders`
- `gift_transactions`
- `ruby_withdraw_requests`
- `economy_transactions`
- `economy_bulk_grants` / recipients

Accounting evidence:

- `economy_journal_entries`

Configuration owned by Economy includes gift catalog and Economy rule tables.
Game catalog/round/risk tables remain Game Platform-owned.

## Mutation flow

`caller -> Economy command -> EconomyTransaction.begin -> domain checks/row locks -> mutation -> ledger + balanced journal -> outbox -> balance assertion -> commit`

The transaction record, ledger/journal and outbox publication are committed
atomically.

## Accounting model

The existing wallet/pool ledgers remain the operational materialization model.
The balanced journal provides explicit debit/credit evidence per transaction and
currency. It is append-only and does not become a competing wallet balance.

## Reconciliation

A bounded reconciliation pass runs periodically from the Economy bulk-worker
runtime. It never writes repairs. Any mismatch becomes an operational incident.

## Cross-domain projections

VIP/SVIP status may be maintained as an Economy-derived projection from
recharge/value history. That projection does not grant Economy authority over
identity/profile fields.

## Security

Production uses isolated Economy credentials and `deploy/postgres/economy-ownership.sql`.
Other services must not receive `funkey_economy_runtime`.

## Observability

Use standard HTTP/DB traces and metrics plus Economy transaction/outbox metrics,
bulk-worker health, and reconciliation mismatch gauges.

## Rollback

Keep one financial writer throughout rollback. Never dual-write Economy from
core and Economy Service simultaneously.
