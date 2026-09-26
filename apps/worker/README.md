# FunKey Worker Platform

Chunk 30 turns the previous catch-all worker into explicit JetStream execution pools using one immutable image.

Pools: `general` (transactional outbox relay), `notification`, `media`, `fanout`, and `maintenance`. The historical `analytics` pool remains deliberately inactive; Chunk 37 uses the separate `kafka-event-bridge` so operational workers never acknowledge analytics copies. Each operational event type has one pool owner. Unexpected events are dead-lettered instead of silently acknowledged.

Handlers have bounded in-flight concurrency and JetStream ack-pending limits. Source messages are acknowledged only after successful idempotent handling; retryable failures use bounded NAK/backoff and terminal failures publish to `funkey.dlq.<event-type>` first.

Chunk 30 removes OpenAI image moderation, physical object deletion, media-retention cleanup, Vibes fanout, and Google Drive backup/restore from public request latency. FCM delivery is already isolated in the Notification provider worker. Raw media upload/transcoding is intentionally completed in Chunk 31.

All pools expose `/live`, `/ready`, and `/metrics` on port 8082. `WORKER_POOL` selects the runtime contract.
