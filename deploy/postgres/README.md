# PostgreSQL platform deployment

This kustomization contains the provider-neutral Chunk 18 pooler and PostgreSQL metrics edge.

## Required external configuration

Before applying outside local/dev, provide:

- `POSTGRES_HOST` and `POSTGRES_DB` in `funkey-config`;
- `funkey-pgbouncer-auth/userlist.txt` containing only approved application login credentials;
- `funkey-postgres-monitoring/database_url` for a dedicated read-only monitoring role;
- application `database_url` secrets pointing to `funkey-pgbouncer:6432`;
- application `MIGRATION_DATABASE_URL` secret pointing directly to PostgreSQL;
- PostgreSQL `pg_stat_statements` enabled by the provider/admin;
- role/database timeout defaults matching the architecture contract.

The checked-in `postgres.example.invalid` is deliberately non-routable. A production deployment is incomplete until environment-specific GitOps/secret configuration replaces it.

## Security

PgBouncer uses SCRAM client authentication and TLS to PostgreSQL. The auth file is a Kubernetes Secret, never a ConfigMap. The monitoring role is read-only and should have only `pg_monitor`/equivalent statistics privileges.

Do not give the exporter the application write credential.

## Service extraction

When a business service receives its own login, update the PgBouncer auth secret/managed pool configuration and restrict the PostgreSQL role to that service's owned schema. Do not preserve monolith-wide write grants as a convenience.


## Inbox service role boundary

After Alembic reaches the Chunk 23 head, run `deploy/postgres/inbox-ownership.sql` with a provider/admin or migration role. It creates the NOLOGIN `funkey_inbox_owner` and `funkey_inbox_runtime` group roles, transfers ownership of chat/call tables, grants Inbox DML only to the runtime group, and grants bounded identity reads.

Provision the actual production Inbox LOGIN externally, grant it membership in `funkey_inbox_runtime`, and store its PgBouncer URL as `INBOX_DATABASE_URL` in `funkey-inbox-secrets`. Do not grant `funkey_inbox_runtime` to the core API login. The migration/admin role must retain the ability to SET ROLE to `funkey_inbox_owner` for later Alembic changes.

Stories are intentionally excluded from the Inbox ownership script in Chunk 23.

## Vibes service role boundary

After Alembic reaches the Chunk 24 head, run `deploy/postgres/vibes-ownership.sql` with a provider/admin or migration role. It creates NOLOGIN `funkey_vibes_owner` and `funkey_vibes_runtime` roles, transfers Vibes tables to the Vibes owner, grants Vibes DML only to the runtime group, and grants bounded reads of identity/social context plus insert-only access to the transactional event outbox.

Provision the production Vibes LOGIN externally, grant it membership in `funkey_vibes_runtime`, and store its PgBouncer URL as `VIBES_DATABASE_URL` in `funkey-vibes-secrets`. Do not grant `funkey_vibes_runtime` to the core API login after cutover.


## Chunk 25 query and storage policy

Hot route query ceilings live in `backend/app/core/query_budget.py` and are emitted by the core API plus the extracted Inbox and Vibes services. CI runs PostgreSQL `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` against seeded hot-query shapes and verifies the Chunk 25 indexes are actually used.

`contracts/database/storage-policy.json` deliberately keeps read replicas and table partitioning disabled until measured evidence and stale-read/partition-pruning semantics are documented. Redis remains non-authoritative and must preserve correctness when lost.
