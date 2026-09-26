# Social

## Purpose

Own follows, blocks, relationship/love-bond state and family membership.

## Current deployable

`apps/profile-social-service` owns social mutations behind stable core public
paths.

## Owns

- `user_follows`
- `user_blocks`
- `love_bonds` / requests
- family membership state

Family community chat is **not** social-owned; Inbox Service owns the durable
conversation/message state for family chat.

## Does not own

Wallet/Economy value, Inbox message storage, room state, realtime transport or
media transport.

## Failure/idempotency

Relationship/follow commands require transactional uniqueness/conflict handling.
Committed social state must not be rolled back because a downstream notification
or Inbox delivery is unavailable.

## Operations

See `docs/architecture/identity-profile-social-services.md` and
`docs/runbooks/identity-profile-social-services.md`.

## Migration status

Chunk 27 extraction is complete for social/love-bond/family-membership mutation.
Family economy rankings remain read-only projections; family chat remains Inbox.
