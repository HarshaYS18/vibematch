# Authentication / Identity

## Purpose

Authenticate users and own durable account/security/session/device state.

## Current deployable

`apps/identity-service` is the Chunk 27 mutation authority. Core preserves stable
`/api/v1/auth` compatibility routes and bounded composite reads.

## Owns

- account/security columns and auth identities
- login history
- durable identity sessions and devices
- roles/special permissions
- user/device bans
- access-token issuance bound to durable session IDs

## Does not own

Profile display/social graph, rooms, Economy value, realtime routing or media
transport.

## Realtime relationship

Identity/API issues short-lived signed realtime capabilities. Go verifies them
locally; the gateway does not become session/account authority.

## Database ownership

`deploy/postgres/identity-ownership.sql` grants mutation rights to Identity.
Core receives reader privileges only where required.

## Security

Signing keys, Google OAuth audience validation, bans, session revocation and
dev-login gating are security-critical. Fail closed on ambiguous protected auth.

## Operations

See `docs/architecture/identity-profile-social-services.md` and
`docs/runbooks/identity-profile-social-services.md`.

## Migration status

Chunk 27 extraction is complete. New access tokens carry durable session IDs;
the finite legacy-token compatibility window ends by normal expiry.
