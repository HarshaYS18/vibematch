# Chunk 27: Identity / Profile / Social Boundaries

## Decision
FunKey deploys two coherent services rather than tiny services: Identity and Profile/Social. Public mobile URLs remain unchanged through the core compatibility facade.

Identity owns authentication, account/security state, durable devices/sessions, roles, special permissions and user/device ban state. The existing admin and user/device-ban routers execute inside Identity and are exposed through exact compatibility proxies. Profile/Social owns profile mutation/display state, custom display IDs, canonical stealth state, social relationships and family membership.

## Safe users-table migration
The existing users table mixes account and profile columns. A big-bang copy would create dual-write and mobile-version risk. Chunk 27 therefore keeps one physical row while enforcing column-level mutation rights: Identity owns the table and account/security columns; Profile/Social can update only the declared profile columns.

This is a migration mechanism. New mixed-purpose columns are forbidden.

## Durable sessions
New access tokens contain sid. identity_sessions and identity_devices make revocation and device state durable. For sid-bearing tokens, non-Identity services verify the session through Identity's internal API; they do not read identity_sessions directly. Pre-Chunk-27 tokens remain valid only until normal expiry to avoid forcing deployed clients to log in again.

## Routing
/api/v1/auth/** routes to Identity.
/api/v1/social/**, /love-bonds/**, /families/** and /profile-display/** route to Profile/Social.
/users/** remains a composite read facade, but profile mutation and profile-visit writes call Profile/Social internally.

## Invariants
Core may compose reads but must not regain extracted mutation authority. Identity must not mutate public profile/social/family truth. Profile/Social must not mutate login, account-status, device or session columns. Each service uses distinct DB credentials and bounded pools.


## Read-only compatibility roles
The legacy core API still composes cross-domain reads during migration. PostgreSQL therefore exposes funkey_identity_reader and funkey_profile_social_reader. The production core login may be a member of these reader roles only; it must not inherit either domain runtime mutation role.

Profile display may read Economy-owned wallet/ledger/rule projections, but Profile/Social has SELECT-only grants for those tables. Profile rendering is forbidden from creating wallets or synchronizing VIP state.
