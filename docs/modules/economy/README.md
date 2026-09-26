# Economy

## Purpose

Provide the single Tier-0 authority for FunKey value movement and financial
auditability.

## Current deployable

`apps/economy-service` is the exclusive financial writer. Core may retain stable
public compatibility/read-orchestration surfaces through a SELECT-only Economy
reader role.

## Owns

- wallet balances and wallet ledger
- coin supply pools and pool ledger
- game financial pools and pool ledger
- gift financial settlement
- recharge/coin sale/ruby conversion/withdrawal value state
- mission reward credits
- Economy transaction/idempotency records
- balanced accounting journal
- durable house-liability reservations
- Lucky Packet funding/claim/refund escrow
- bulk financial grants
- Economy-owned gift/rule configuration

## Does not own

Identity/profile truth, room state, game lifecycle/risk/stats, realtime transport
or client state. Game Platform calls Economy for value; Economy does not create
game rounds as lifecycle authority.

## Transaction contract

Cross-domain writes require `transaction_id`, `idempotency_key` and
`business_reference`. The transaction record, balance mutation, operational
ledger, balanced journal and outbox event commit atomically.

## Accounting

`user_wallets` plus wallet/supply/game pool ledgers are operational balance truth.
`economy_journal_entries` is append-only balanced debit/credit evidence for value movement.
`economy_house_reservations` is durable liability truth and the pool reserved-balance column is
its reconciled materialization. These invariants are continuously checked by the Economy worker.

## Database ownership

`deploy/postgres/economy-ownership.sql` defines owner/runtime/reader roles.
Only Economy receives mutation rights. Core and other services must never be
granted `funkey_economy_runtime`.

## Observability

Trace transaction/business reference across caller -> Economy -> DB -> outbox.
Monitor DB pool/latency, idempotency conflicts, outbox lag, bulk jobs and
reconciliation mismatch gauges.

## Operations

See `docs/architecture/economy-service.md`,
`docs/runbooks/economy-service.md`, and `apps/economy-service/README.md`.

## Migration status

Chunk 25 cutover is complete after the Chunk-32 audit repair. The old staged
internal-only wording is superseded; Economy is now the declared exclusive
financial writer with core compatibility reads only.

## Change checklist

Never introduce a financial write outside Economy. New mutation types need
stable idempotency/business identity, transactionally consistent ledger/journal
evidence, outbox publication, reconciliation coverage, and rollback rules.
