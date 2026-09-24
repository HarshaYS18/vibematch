# Notifications

## Purpose

Own FunKey in-app notification truth and push-delivery orchestration without allowing feature services, generic workers or FCM to become notification authority.

## Responsibilities

- in-app notification persistence/read state
- device-token lifecycle
- per-user push preferences and quiet hours
- versioned notification templates
- push frequency caps, dedupe and collapse keys
- durable provider delivery status, leases and retries
- invalid-token cleanup

## What it owns

PostgreSQL tables: `user_notifications`, `push_device_tokens`, `notification_preferences`, `notification_templates`, `notification_deliveries`.

## What it does not own

Identity/profile truth, Inbox messages, Vibes posts, room state, wallet/economy value, realtime transport or FCM infrastructure. FCM is an external delivery transport only.

## Contracts

Public compatibility remains `/api/v1/notifications/*` and `/api/v1/push/*` through the core proxy. Internal producers use versioned notification intent events or the authenticated `/internal/notifications/intents` boundary. The generic NATS worker may submit intents but has no Notification table write authority.

## Failure / idempotency

Recipient + dedupe key is unique. Notification/device pairs are unique delivery rows. Provider workers lease due work with `FOR UPDATE SKIP LOCKED`; transient provider failures retry with bounded backoff, invalid tokens are deactivated, quiet hours defer and frequency caps suppress.

## Observability and operations

API exports standard HTTP/DB metrics and OpenTelemetry traces. Provider worker emits structured delivery status/error logs and health endpoints. See `docs/runbooks/notification-service.md`.

## Deployment

API image: `funkey-notification` on port 8090. Provider worker uses the same immutable image with `provider_worker.py`. Production requires isolated `NOTIFICATION_DATABASE_URL`, a strong `NOTIFICATION_INTERNAL_TOKEN`, FCM HTTP v1 project configuration and a mounted service-account secret.

## Migration status

Chunk 29 extracted. Core public URLs are compatibility proxies; PostgreSQL ownership grants prevent core/generic worker writes after cutover.
