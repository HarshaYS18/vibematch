# Trust / safety / fraud / Economy integrity

Chunk 44 unifies risk signals behind deterministic reason-coded decisions while
preserving existing moderation and Economy authorities.

Signals may come from account/device velocity, payment/gift patterns, game
settlement anomalies and moderation history. The central policy returns a score,
action and reason codes; it does **not** silently rewrite balances, delete
evidence or become the ledger.

High-impact actions are temporary/reversible holds plus manual review unless an
owning policy explicitly authorizes otherwise. Moderation cases and Economy
transactions keep durable evidence/audit trails.

Core integrity invariants remain: no negative balance creation, no duplicate
settlement, idempotent financial mutations, reconciliation jobs and explicit
operator-visible anomalies.
