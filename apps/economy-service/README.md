# FunKey Economy Service

Economy Service is the Tier-0 financial authority for FunKey.

## Authority

Economy is the exclusive writer for:

- user wallet balances and wallet ledger
- coin supply pools and supply ledger
- game financial pools and pool ledger
- gift financial settlement
- coin sales/recharges and ruby conversion/withdrawal
- mission reward credits
- bulk financial grants
- Economy transaction/idempotency records
- balanced accounting journal entries
- gift catalog/economy rule configuration owned by Economy

Game Platform owns game lifecycle/risk/stats, not value. Profile/Social owns
profile/social truth, not wallet value. Core may perform bounded composite reads
through the Economy reader role but must not receive Economy mutation rights.

## Transaction contract

Every cross-domain financial mutation carries:

- `transaction_id`
- `idempotency_key`
- `business_reference`

Retries with the same identity return the stored result. Reusing an idempotency
key with different request content, or rebinding a transaction ID, fails closed.

Wallet and pool value mutations append their operational ledger evidence plus balanced debit/credit
journal legs inside the same Economy transaction. Transaction completion checks
journal balance before committing and publishes the durable outbox event in that
same transaction.

## Accounting and reconciliation

`user_wallets` plus `wallet_ledger` remain operational balance truth.
`economy_journal_entries` is an append-only balanced accounting/audit projection;
it does not become a second balance authority.

The Economy bulk-worker runtime continuously performs bounded, read-only
reconciliation:

- wallet materialized balance vs the latest wallet ledger `after_balance`
- supply-pool materialized balance vs the latest supply ledger
- game-pool materialized balance vs the latest game-pool ledger
- reserved liability vs active `economy_house_reservations`
- debit total vs credit total by Economy transaction and currency

A mismatch is an incident. The worker never "repairs" balances automatically.

## Public compatibility

Stable mobile/public URLs remain available through the core API. Extracted
families are proxied to Economy Service; read/orchestration facades may remain in
core using the SELECT-only Economy reader role. All value mutations delegate to
Economy Service.

## PostgreSQL roles

`deploy/postgres/economy-ownership.sql` defines:

- `funkey_economy_owner` — object ownership
- `funkey_economy_runtime` — Economy service mutation role
- `funkey_economy_reader` — bounded SELECT-only compatibility role

Never grant `funkey_economy_runtime` to core-api, Game Platform, the generic Worker Platform,
Realtime, Profile/Social or other domains. The Economy-owned bulk/reconciliation worker is part of
the Economy boundary and uses Economy-scoped credentials.

## Operations

- API: `8088`
- health: `/live`, `/ready`
- metrics: `/metrics`
- database: `ECONOMY_DATABASE_URL`
- public base: `/api/v1`
- internal mutation base: `/internal/economy`
- Economy worker: bounded bulk grants + Lucky Packet expiry finalization + periodic reconciliation

See `docs/architecture/economy-service.md` and
`docs/runbooks/economy-service.md`.
