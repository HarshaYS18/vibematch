# Kafka Event Bridge tests

- `test_contracts.py` covers domain-family routing, partition-key stability and sensitive-key rejection.
- `test_topics.py` locks the canonical topic catalogue and retention/partition invariants.
- `test_bridge.py` proves source ACK-after-Kafka-ACK, retry-on-Kafka-failure, filtering and poison-event quarantine.
- `test_consumer.py` validates DLQ provenance and bounded poison payload capture.
- `test_replay.py` enforces timezone-aware, bounded, isolated replay windows.\n- `test_config.py` locks TLS/SASL fail-closed configuration.\n- `test_metrics.py` locks bounded-cardinality JetStream lag gauges.

The repository architecture guard additionally prevents direct Kafka imports outside this platform boundary.
