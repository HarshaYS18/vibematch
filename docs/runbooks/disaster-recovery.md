# Disaster recovery

A backup is not considered usable until a restore drill proves it.

## Required evidence

For every drill record the UTC start/end time, source backup/PITR position,
target isolated environment, schema revision, row/ledger reconciliation checks,
object-store checks, operator and achieved RPO/RTO.

## PostgreSQL

Use provider PITR/WAL restore into an isolated staging database. Never point a
restore drill at production. Run migrations/status checks, authority-owner smoke
tests and Economy ledger reconciliation before declaring success.

## Redis

Do not restore Redis as business truth. Rebuild cache/presence/routing state from
authoritative systems and reconnecting clients.

## Kafka / OpenSearch / Recommendation

Kafka analytics may be restored/replayed according to retention policy.
OpenSearch and Recommendation Redis are projections: rebuild them from durable
events/backfill rather than promoting stale snapshots to authority.

## Region loss

Follow `region-failure.md`. Fail traffic only after authoritative DB state is
confirmed. Economy writer-region changes are explicit incident actions and must
never result in two writable regions.

## Media

Restore/version object storage using provider retention/versioning policy, then
verify DB metadata references and CDN reachability.
