# FunKey Identity Service

Chunk 27 extracts authentication, account identity and durable session/device authority.

## Responsibilities
Identity owns account and security mutation, auth identities, login history, identity devices, identity sessions, login issuance, and session validation.

## Non-responsibilities
It does not own public profile presentation, social graph, family membership, wallet/economy, rooms, Inbox, Vibes, search or recommendation state.

## Interfaces
Public API: /api/v1/auth/** through the core compatibility facade.
Internal API: /internal/identity/verify and /internal/identity/sessions/revoke.
Operations: /live, /ready, /metrics.

## Session compatibility
New JWTs carry sid and are backed by identity_sessions. Other services verify sid-bearing tokens through /internal/identity/verify rather than reading Identity tables. Tokens issued before Chunk 27 contain no sid and remain valid only until their original JWT expiration. Do not extend that compatibility window.

## Database ownership
Production uses IDENTITY_DATABASE_URL with service-isolated credentials bound to funkey_identity_runtime. Pool size and replica count are bounded by the PostgreSQL connection budget.

## Failure and rollback
If Identity is unavailable, new authentication fails closed with 503 while unrelated APIs remain available. The migration is additive; rollback restores prior routing but does not drop session/device tables.

## Observability
Use standard OpenTelemetry tracing, request ids, query counters, DB pool metrics and alerts. Never put tokens, email addresses or device identifiers into metric labels.
