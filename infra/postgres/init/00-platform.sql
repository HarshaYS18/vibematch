-- Local-development PostgreSQL platform bootstrap only.
-- Production extension/parameter changes are provider-admin prerequisites.

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

ALTER ROLE funkey SET statement_timeout = '3s';
ALTER ROLE funkey SET lock_timeout = '1s';
ALTER ROLE funkey SET idle_in_transaction_session_timeout = '10s';
