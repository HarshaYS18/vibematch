# Notification Service Runbook

Notification Service is the sole database writer for notification rows, device tokens, preferences, templates and provider delivery state. Generic workers submit intents only.

API health: `/live`, `/ready`, `/metrics`. Provider worker health: `:8091/live`, `:8091/ready`.

FCM 429/5xx/network failures move deliveries to `RETRY` with bounded backoff. Invalid/unregistered tokens become `INVALID_TOKEN` and are deactivated. Quiet hours use `DEFERRED`; frequency caps use `SUPPRESSED`. If Notification Service is unavailable, the NATS worker leaves the source event unacked so JetStream retry/DLQ policy applies. If provider workers stop, durable due rows resume after restart/lease expiry.

Recovery: check PostgreSQL, oldest due delivery, failure codes, FCM project/service-account configuration, then restart provider workers. Never create a second writer as a recovery shortcut.

Rollback after database ownership cutover requires explicit role transfer; do not dual-write.

## Credential boundary

If API readiness is healthy but delivery is failing, inspect the provider deployment first. FCM credentials are intentionally mounted only into provider pods; do not add the Firebase service-account secret to the public Notification API deployment as a workaround.
