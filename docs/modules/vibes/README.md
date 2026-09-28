# Vibes

## Purpose

Owns FunKey short-form social content and the bounded feed read model.

## Responsibilities

The Vibes service owns posts, comments, reactions, saves, shares, reports, engagement counters, feed candidate retrieval and the current chronological ranking policy.

## Authority

PostgreSQL in the Vibes service is durable authority for `vibe_posts`, `vibe_comments`, `vibe_comment_reactions`, `vibe_reactions`, `vibe_shares`, `vibe_saves`, and `vibe_reports`.

Redis, Flutter caches, OpenSearch, Kafka/ClickHouse and recommendation outputs are never Vibes content authority.

## Does not own

Identity/social relationships, notifications, Inbox conversations/messages, media objects, realtime transport, search indexes, analytics or recommendation models.

## Public API

Existing `/api/v1/vibes/**` and `/api/v1/admin/moderation/vibes/**` paths are preserved. Production ingress routes them to `funkey-vibes`; the core API has a compatibility proxy only.

Feed responses expose `posts`, `next_cursor`, and `has_more`. Cursors are opaque and ordered by `created_at DESC, id DESC`.

## Internal API

`GET /internal/vibes/posts/{post_id}/fanout` is authenticated by `VIBES_INTERNAL_TOKEN` and used by worker-side publication fanout.

## Events

Published transactionally: `vibes.post.published` and `vibes.media.requested`. The worker consumes them through NATS JetStream.

## Scaling

Feed reads are keyset bounded, eager-load authors, and use set-based viewer like/save queries. Per-post aggregate queries in feed serialization are forbidden by the architecture guard.

## Security

The production Vibes database login receives DML only on Vibes tables, bounded SELECT on identity/social context, and INSERT on the event outbox. Secrets are externally provisioned.

## Observability / rollback

See `docs/runbooks/vibes-service.md`. Chunk 24 migration `20260924_0100` is additive; roll back routing/application code before any schema downgrade.
