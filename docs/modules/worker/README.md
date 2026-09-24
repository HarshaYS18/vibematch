# Worker Platform

## Purpose

Execute durable asynchronous work without turning transport/runtime code into business authority.

## Pools and ownership

The worker image supports general/outbox, notification, media, fanout, maintenance, and analytics-bridge pools. `apps/worker/pools.py` is the executable subject/handler allowlist. Unexpected events are sent to the DLQ. The analytics pool is deliberately zero-replica/unsubscribed until Chunk 37 provides Kafka.

The Worker Platform owns execution, retry, backpressure and DLQ mechanics plus generic worker idempotency markers. Domain truth remains with its owner. Inbox backup jobs are created and mutated through Inbox owner code; Notification intents go through Notification Service.

## External work

Chunk 30 moves OpenAI image moderation, physical object deletion, retention cleanup, Vibes fanout, and Google Drive backup/restore behind durable events. FCM delivery was isolated by Chunk 29. Raw upload/transcoding moves to Media v2 in Chunk 31.

## Retry and idempotency

Explicit JetStream ack, bounded max delivery, bounded pool concurrency, event-specific DLQ, and stable owner job IDs are required. Google Drive uploads tag files with the durable backup job ID and query that property before retrying creation.

## Scaling

General outbox relay starts fixed at one replica. Notification, media, fanout and maintenance scale independently from their own durable consumers. Configured maxima are 5 + 5 + 4 + 5 plus one general relay = the existing aggregate 20-worker connection budget. Analytics remains disabled.

## Observability

Structured completion/retry/DLQ logs, OpenTelemetry pool attributes, and low-cardinality pool-labelled readiness/in-flight/throughput metrics are emitted. Operational endpoints are `/live`, `/ready`, `/metrics`.

See `docs/runbooks/worker-platform.md`.
