# Vibes Service Architecture — Chunk 24

## Decision

FunKey physically extracts Vibes content/feed authority into `funkey-vibes` while preserving existing public API paths. The core API becomes a compatibility proxy only.

## Ownership

Vibes owns posts, comments, post/comment reactions, saves, shares, reports, engagement counters, and bounded feed retrieval. PostgreSQL is durable authority. Recommendation/search systems remain projections.

## Feed read path

Feed reads use keyset pagination on `(created_at, id)`. The query fetches at most `limit + 1`, eagerly loads authors, and resolves viewer like/save state with two set-based queries for the page. `VibePostResponse` reads transactionally maintained counters and performs no count query per item.

The ranking seam is explicit:

`FeedCandidateProvider -> FeedPolicy -> FeedRanker -> FeedRepository`

Chunk 24 intentionally keeps chronological/following semantics. Chunk 39 may replace candidate/ranking implementations without moving content authority.

## Write path

Like, save, share, report and comment mutations update their corresponding post counter in the same database transaction as the authoritative row mutation. Migration `20260924_0100` backfills counters from existing engagement rows and adds the feed cursor index.

## Fanout

Post creation inserts `vibes.post.published` into the transactional outbox before commit. The worker consumes the NATS event, asks the Vibes internal API for a bounded fanout snapshot, creates in-app notifications idempotently, and sends direct-mention Inbox snapshots outside the request path.

Media link/delete is similarly expressed as `vibes.media.requested`. Media remains outside Vibes authority.

## Failure behavior

A Vibes write is successful when Vibes authority commits. Notification/Inbox/media projections may lag and retry without turning a committed post into a failed client request. Feed reads do not depend on Redis, search, recommendation, Inbox, or media availability.

## Rollback

The migration is additive. The core compatibility proxy can be switched back to the prior deployable while the new counters/index remain present. Do not drop counters or restore synchronous follower fanout during an incident.
