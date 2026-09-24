# Economy Service Runbook

## Tier-0 invariant

Economy Service is the exclusive financial writer. Other domains call Economy
APIs and may receive read-only projections; they never receive Economy mutation
credentials.

Financial authority includes wallet/ledger truth, supply pools, gift settlement,
mission reward credits and game financial settlement. Game lifecycle remains
Game Platform authority.

## Health and first checks

Check, in order:

1. Economy `/ready` and DB connectivity.
2. DB pool saturation and statement/lock timeouts.
3. `economy_transactions` for pending/replayed identities.
4. outbox backlog for Economy events.
5. bulk-worker readiness and retry state.
6. reconciliation metrics:
   - `funkey_economy_reconciliation_wallet_mismatches`
   - `funkey_economy_reconciliation_unbalanced_journals`
   - `funkey_economy_reconciliation_failures_total`

Do not clear a mismatch by editing a wallet row.

## Idempotency

Every cross-domain mutation requires `transaction_id`, `idempotency_key`, and
`business_reference`. A completed retry returns the stored result. Conflicting
reuse fails closed.

When a caller times out, query/retry with the original mutation identity. Never
create a new transaction ID until commit outcome is known.

## Balanced journal

Every transaction-layer wallet debit/credit writes two opposite
`economy_journal_entries` legs in the same DB transaction. Completion flushes and
verifies per-currency debit == credit before committing.

The journal is accounting/audit evidence. `user_wallets` + `wallet_ledger`
remain operational balance truth.

## Reconciliation

Reconciliation is read-only and periodic in the Economy bulk-worker runtime.
It compares current wallet balances with the latest ledger `after_balance` and
checks journal balancing.

If mismatches appear:

1. stop/rate-limit the affected mutation family if the count is increasing;
2. capture transaction IDs, business references and ledger/journal rows;
3. determine the authoritative committed operation;
4. create an explicit reviewed corrective Economy transaction if needed;
5. never overwrite historical ledger/journal rows.

## Database ownership

Apply `deploy/postgres/economy-ownership.sql` only after migrations through the
current head are applied. Bind `funkey_economy_runtime` only to Economy service
and its Economy worker credentials. Core receives `funkey_economy_reader` if
composite reads still require direct SQL.

Do not restore core mutation grants as an incident workaround.

## Rollout

1. Apply Alembic.
2. Deploy Economy service with isolated DB credentials.
3. Deploy Economy bulk worker.
4. verify all cross-domain financial callers use `economy_service_client`.
5. apply Economy ownership SQL.
6. verify core/mobile compatibility routes.
7. observe transaction, outbox, reconciliation and DB metrics through soak.
8. only then remove obsolete mutation compatibility code.

## Rollback

Rollback routing before ownership. If an application rollback requires an older
core build, do **not** grant it Economy mutation rights blindly.

Preferred rollback:

1. keep current Economy schema and ownership;
2. route old-compatible public calls through Economy compatibility endpoints;
3. roll Economy implementation back to a schema-compatible image if necessary;
4. preserve `economy_transactions`, wallet ledger and journal history.

Never downgrade or delete financial audit rows during normal rollback.
