# Analytics Sink

Chunk 48 consumes retained Kafka analytics events and writes two disposable
analytical projections:

- ClickHouse for low-latency analytical queries.
- Parquet in long-retention object storage/data lake.

Neither is business authority. Domain correctness remains in owner services and
PostgreSQL. The consumer uses manual offsets and advances only after the batch
has been accepted by both sinks. ClickHouse uses an event-id keyed
ReplacingMergeTree and Parquet object keys are deterministic per event set so
replays are retry-safe enough for analytical projections.

Production requires SASL/TLS Kafka and S3-compatible object storage. Local file
mode exists only for development/testing.
