# FunKey Notification Service

Chunk 29 deployable and sole writer for in-app notifications, push device tokens, push preferences, templates, provider-delivery state, quiet hours, frequency caps, dedupe/collapse behavior, retries and invalid-token cleanup.

Feature services do not call FCM and do not write Notification tables. They emit notification intents/events. The NATS worker submits idempotent intents to `/internal/notifications/intents`; `provider_worker.py` performs FCM delivery asynchronously from durable leased delivery rows.

A recipient + dedupe key creates at most one notification. Each active device gets at most one delivery row. Provider workers use `FOR UPDATE SKIP LOCKED`, bounded retry/backoff and invalid-token deactivation. FCM is transport only; PostgreSQL is authority.

Core preserves `/api/v1/notifications/*` and `/api/v1/push/*` through `notification_proxy`, so Flutter UI/API paths do not change.

Operations: API `8090`; provider health `8091`; database `NOTIFICATION_DATABASE_URL`; internal auth `NOTIFICATION_INTERNAL_TOKEN`.
