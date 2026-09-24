# Economy Service Runbook

## Tier-0 invariant
Economy is the exclusive financial writer for wallet/ledger truth, supply pools, gift financial settlement, mission reward credits, and game financial settlement after cutover. Other domains call Economy APIs; they never receive Economy database credentials.

## Current staged rollout
The initial service is internal-only. Public/mobile Economy routes remain on core until all cross-domain callers and side effects have been migrated. Do not apply exclusive Economy ownership SQL before that cutover is complete.

## Idempotency
Every cross-domain mutation requires transaction_id, idempotency_key, and business_reference. Completed retries return the stored result. The same idempotency key with different content or a transaction ID rebound to another idempotency key fails closed.

## Reconciliation
Continuously compare wallet balances against ledger continuity and latest ledger after_balance. Alert on negative balances, duplicated business operations with different transaction IDs, missing transaction metadata for service-originated writes, or inconsistent house-pool reserves.

## Cutover order
1. Apply Alembic through the Economy foundation migration.
2. Deploy Economy with isolated credentials and internal APIs only.
3. Cut Store, Missions, Games, gifts and other financial callers to Economy APIs.
4. Remove cross-domain writes from Economy reads and emit durable projection events.
5. Apply Economy ownership SQL.
6. Switch public compatibility routes to Economy.
7. Remove legacy core mutation rights.

## Rollback
Rollback routing/client calls first. Do not drop economy_transactions or ledger transaction metadata; they are durable financial audit state.
