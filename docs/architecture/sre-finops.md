# SRE / FinOps / production certification

Chunk 50 defines measurable SLO targets for API/GraphQL, room join, realtime,
Inbox, wallet, media and mobile crash-free sessions. Error budgets govern
rollout pace; exhausting a budget freezes non-essential rollouts rather than
weakening the SLO.

FinOps is expressed as unit costs instead of raw monthly spend: API/realtime/
Kafka units, room hour, media participant minute, egress, ClickHouse/object
storage and push delivery. These metrics guide engineering decisions but never
become billing authority.

Production certification is evidence-based. The repository defines required
synthetic, 6h/24h soak, reconnect/media load, database/Redis/NATS/Kafka/region
failure and rollback scenarios. The validator refuses incomplete or non-passing
evidence. No capacity or SLO-compliance claim is valid merely because manifests
or test scripts exist.
