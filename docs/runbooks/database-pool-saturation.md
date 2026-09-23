# PostgreSQL / PgBouncer saturation

**Owner:** Platform / Database

## Symptoms

- API/worker database checkout timeouts
- PgBouncer waiting-client count increases
- PostgreSQL connection count approaches the configured server budget
- request latency rises while CPU remains moderate
- long-running transactions or lock counts increase

## Diagnose

Check, in order:

1. application pool checked-out versus configured size;
2. PgBouncer client, active server, idle server, and waiting client counts;
3. PostgreSQL active connections versus `max_connections`;
4. long-running and idle-in-transaction sessions;
5. blocking locks and deadlock counter;
6. top `pg_stat_statements` query IDs by total/mean execution time;
7. recent autoscaling/rollout surge.

Do not paste SQL parameters, credentials, message bodies, or payment data into incident notes.

## Safe mitigation

- pause further application scale-out if it would exceed the budget;
- stop nonessential batch work;
- identify and fix long transactions/blockers;
- reduce traffic or concurrency before increasing server connections;
- use the established direct admin connection only for controlled database operations.

## Dangerous actions

Do not raise PostgreSQL `max_connections`, PgBouncer server caps, SQLAlchemy overflow, or HPA maxima independently. Do not bypass PgBouncer with application direct DSNs during saturation. Do not kill an unknown transaction performing wallet/ledger settlement without reconciliation.

## Recovery

Confirm waiting clients return to zero/baseline, pool utilization normalizes, no unexpected deadlocks remain, latency/error rates recover, and ledger/idempotency reconciliation is clean for any ambiguous writes.

After the incident, update measured capacity evidence before changing any budget.
