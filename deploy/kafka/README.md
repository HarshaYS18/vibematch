# Staging Kafka KRaft integration cluster

This package is for **staging integration and failure testing**, not production.

It renders three KRaft broker/controller nodes, replication factor 3, min ISR 2, a PDB, network policy, bootstrap/per-node services and an idempotent topic-provisioning Job using the Kafka Event Bridge image.

Production must use the managed Kafka prerequisite documented in `docs/EXTERNAL_PREREQUISITES.md`. The production overlay intentionally does not include `deploy/kafka`.

The staging cluster uses plaintext only inside the Kubernetes namespace because it is an integration fixture. Production is `SASL_SSL` and least-privilege ACLs.
