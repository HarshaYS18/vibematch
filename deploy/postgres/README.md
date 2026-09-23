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
