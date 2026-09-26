# Compatibility / feature flags / release safety

Chunk 49 defines explicit versions for REST, realtime envelopes, domain events,
persisted GraphQL operations, the game bridge and asset manifest.

Mobile skew is expected: the server must preserve the current supported contract
and at least the previous supported client generation during rollout. Breaking
changes require a version bump, usage evidence and a deprecation window.

Client-visible boolean flags use OpenFeature-compatible evaluation concepts:
flag key, targeting context, deterministic percentage rollout, platform,
app-version, cohort and region targeting, variant/reason metadata and a kill
switch. Flag evaluation is not authorization; security/permission checks remain
in owner services.

Migrations use expand -> compatible rollout -> observe -> contract. A flag may
gate exposure but must not hide an unsafe irreversible schema transition.
