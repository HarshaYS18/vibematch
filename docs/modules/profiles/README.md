# Profiles

## Purpose

Own profile mutation/display state, visits and profile privacy behavior.

## Current deployable

`apps/profile-social-service` is the mutation authority. Core may compose
read-only profile/economy views but does not mutate profile-owned state.

## Owns

- documented profile columns on the legacy users row through scoped grants
- stealth/profile display state
- profile audits/visits
- profile media activation after approved moderation

## Does not own

Account/security state, wallet/Economy value, room authority, realtime transport
or media bytes.

## Database boundary

Identity owns the physical `users` table while Profile/Social receives UPDATE
rights only for documented profile columns during the safe shared-table
migration. This is a column-scoped mutation boundary, not shared authority.

## Privacy

Stealth/visibility/block rules must be applied before profile rendering and
visits. Read caches must not bypass a newer privacy decision.

## Operations

See `docs/architecture/identity-profile-social-services.md` and
`docs/runbooks/identity-profile-social-services.md`.

## Migration status

Chunk 27 profile mutation and visit side effects are extracted to
`profile-social-service`.
