# Recommendation platform runbook

Check service readiness, Kafka consumer lag and recommendation Redis health.
If Redis is lost, allow the projection to rebuild from Kafka; do not restore it
from an authoritative database snapshot or make it business truth.

If ranking quality regresses, roll back the ranker/model version while keeping
the event history. If the service is down, clients may show non-personalized
content; commands must continue.

Before promotion verify consumer restart, duplicate-event tolerance, Redis flush
rebuild and deterministic replay of a fixed event window.
