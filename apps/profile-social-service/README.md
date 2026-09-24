# FunKey Profile / Social Service

Chunk 27 extracts profile mutation, profile display state, social relationships, love bonds and family membership.

## Responsibilities
The service owns user_follows, user_blocks, love_bonds, love_bond_requests, profile visit/display state and family membership/current family records. Profile fields remain in the existing users row during migration, protected by column-scoped PostgreSQL grants.

## Non-responsibilities
Account/login/security state belongs to Identity. Wallet/economy, Inbox persistence, rooms, Vibes and media objects remain separate authorities.

## Interfaces
Public API: /social/**, /love-bonds/**, /families/** and /profile-display/** behind the core facade.
Internal API: profile mutation, profile-visit recording, custom-ID assignment and canonical stealth updates used by compatibility/admin facades. Authenticated public handlers delegate sid/session validation to Identity and never read identity_sessions directly.
Operations: /live, /ready, /metrics.

## Cross-domain seams
Family chat uses the Inbox adapter. Relationship-card inventory remains a documented commerce compatibility seam because Store currently sells those cards. Do not broaden this exception.

## Failure and rollback
Writes fail closed with bounded 503 responses when the service is unavailable; unrelated core domains remain healthy. Rollback is routing-first and retains additive schema.

## Observability
Use standard OpenTelemetry traces, request ids, query counters and DB pool metrics. Avoid high-cardinality user identifiers in metric labels.


## Read-only Economy projection
Profile rendering reads user_wallets, wallet_ledger, gift_transactions and economy rule tables with SELECT-only privileges. The profile service must never create wallets, synchronize VIP rows, or mutate Economy truth as a side effect of a GET/profile response.
