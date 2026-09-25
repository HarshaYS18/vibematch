# Worker Platform Runbook

Identify the affected `WORKER_POOL` first. Check readiness, JetStream consumer lag, `funkey_worker_in_flight`, retries and DLQ growth. A healthy general relay does not imply media/fanout/maintenance health.

Pool map: general = PostgreSQL outbox relay; notification = notification intents; fanout = Vibes publication fanout; media = media link/moderation/delete; maintenance = Inbox backup/restore and retention cleanup; analytics = disabled until Kafka.

Transient dependency failures NAK with bounded backoff. Validation errors and exhausted retries publish to the event-specific DLQ before source acknowledgement. If DLQ publication fails, the source is NAKed again.

Google Drive jobs remain durable in Inbox. Provider failure uses the same job ID on retry; upload creation is recovered through the `funkey_job_id` Drive property. Media delete failure leaves retryable state and JetStream redelivery retries physical deletion.

Recovery: fix the dependency, inspect DLQ reason and owner state, then replay with the original event/job identity. Never create a second business authority to clear a backlog.

Scale only the affected pool. The Chunk 30 maxima are notification 5, media 5, fanout 4, maintenance 5 plus one general relay = 20 aggregate DB-using worker replicas.

During deploy, stop fetching, allow up to `WORKER_SHUTDOWN_GRACE_SECONDS` for in-flight work, then drain NATS. Verify no retired catch-all `vibes.>` consumer remains.

Chunk 31 replaces raw API media upload and introduces processing variants/transcoding. Chunk 37 activates analytics with the NATS-to-Kafka bridge.


## Vibes mention fanout recovery

A `vibes.post.published` event is not marked processed until Notification and required Inbox mention effects succeed. Notification intents and Inbox messages carry per-recipient stable dedupe identities. If Inbox is unavailable, leave the event retryable; after recovery replay the original event identity. Never insert a processed marker manually to clear the backlog, because that would permanently skip the missing Inbox side effect.
