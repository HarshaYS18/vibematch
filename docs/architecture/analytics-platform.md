# Analytics / ClickHouse / data-lake architecture

Chunk 48 turns Kafka's retained analytics stream into two projections:

Kafka -> Analytics Sink -> ClickHouse
                     -> Parquet/object storage

ClickHouse serves analytical queries and dashboards. Parquet is the long-term,
portable lake format. Neither path is allowed to make authentication, wallet,
room, moderation, game-settlement or other business decisions by itself.

The sink commits Kafka offsets only after both sinks accept a batch. ClickHouse
is event-id keyed with ReplacingMergeTree to tolerate replay duplicates. Parquet
object names are deterministic hashes of the batch event IDs and are partitioned
by UTC date/topic family.

Feature/ML pipelines must be reproducible from versioned Kafka/lake data and
record their model/feature version. Production object storage is private,
encrypted, retention-governed and follows the privacy classification contract.
