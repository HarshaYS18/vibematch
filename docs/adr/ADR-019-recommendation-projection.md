# ADR-019: Recommendation as disposable projection

Status: Accepted and implemented in Chunk 39

Recommendation consumes retained Kafka events, computes bounded features/scores
and stores short-lived feed projections in Redis. Recommendation output never
becomes content, wallet, identity, room or authorization authority.

A Recommendation outage may reduce personalization but must not prevent core
commands. Redis projections are reconstructable from Kafka retention/replay.
