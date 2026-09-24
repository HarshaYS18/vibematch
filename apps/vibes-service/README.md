# FunKey Vibes Service

Chunk 24 extracts durable Vibes/content authority from the core API while keeping the existing public `/api/v1/vibes/**` and moderation paths stable.

## Owns

- Vibe posts and comments
- post/comment reactions
- saves, shares and reports
- denormalized post engagement counters
- bounded feed retrieval and the chronological ranking seam

PostgreSQL is durable authority. `VIBES_DATABASE_URL` must use a dedicated production login. Redis/search/recommendation systems are projections only.

## Read contract

Feed endpoints use keyset pagination on `(created_at, id)`, fetch `limit + 1`, and return `next_cursor` plus `has_more`. Post counters are stored on `vibe_posts`; viewer liked/saved state is loaded with set-based queries instead of per-post queries.

## Ranking seam

`FeedCandidateProvider -> FeedPolicy -> FeedRanker -> FeedRepository` keeps initial chronological/following behavior while allowing Chunk 39 recommendation candidates/ranking to evolve without moving content authority.

## Fanout and media side effects

Vibe creation commits the post and transactional outbox events together. Mention/follower fanout and media-link/delete side effects run in the worker after commit. The request path never loops over followers or synchronously sends mention Inbox snapshots.

## Public routing

Production ingress routes `/api/v1/vibes/**` and `/api/v1/admin/moderation/vibes/**` directly here. Core FastAPI retains only a compatibility proxy for local development and rollback.

## Required production settings

`VIBES_DATABASE_URL`, `VIBES_INTERNAL_TOKEN`, JWT/auth settings, and normal database/pooler settings are provided externally. No production credential belongs in this repository.
