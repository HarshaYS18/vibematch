# Analytics platform runbook

If ClickHouse fails, stop offset progress and restore ClickHouse before allowing
the consumer to drain. If object storage fails, likewise preserve the Kafka
offset; never acknowledge a batch only because one sink succeeded.

For duplicate analytical rows after a partial retry, use event_id-aware queries
or ClickHouse FINAL where necessary; do not mutate domain databases to "repair"
analytics.

For a rebuild, create a new table/dataset version and replay a bounded Kafka/lake
window. Validate row counts, event-id uniqueness, lag and dashboard results
before switching readers.
