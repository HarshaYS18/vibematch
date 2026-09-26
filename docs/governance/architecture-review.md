# Architecture review policy

Architecture review is required before:

- moving durable authority between services
- adding a new durable datastore, broker or application WebSocket
- creating a new financial mutation path
- changing event/realtime/GraphQL/game compatibility contracts
- introducing active-active durable writes
- changing privacy/security classifications
- bypassing canonical Flutter networking/state/resource boundaries

The change must include an ADR or RFC, migration sequence, rollback plan,
observability/SLO impact, ownership updates and architecture/conformance guards.

Reviewers evaluate the proposed authority graph, failure modes, idempotency,
data privacy, operational recovery, scaling limits and client skew. "It works
locally" is not sufficient evidence for a distributed architecture change.
