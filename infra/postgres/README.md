# PostgreSQL platform assets

This directory contains local bootstrap and production-operations reference assets for Chunk 18.

- `init/00-platform.sql` enables local `pg_stat_statements` and safe timeout defaults.
- `audit-ownership.sql` audits schema/table ownership and broad grants before/after service extraction.

Production managed PostgreSQL usually requires provider/admin actions for extensions, parameter groups, backups, replicas, PITR, and monitoring roles. Do not run local bootstrap SQL blindly against production.

## Future service role policy

Create one login per extracted service and one owned schema/ownership boundary. Do not grant a service broad write access to another service's schema. Temporary migration grants must have an owner, reason, expiry/cutover condition, and follow-up revocation.

The canonical Alembic graph remains owned by the platform until a later, explicit migration architecture decision changes it.
