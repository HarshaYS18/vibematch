# TURN outage

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Users on restrictive networks fail ICE while direct-network participants still connect.

## Dashboards and metrics to inspect

TURN auth rejects, allocation count, relay bandwidth, UDP/TCP reachability, ICE candidate pair type, certificate expiry.

## Immediate actions

Confirm TURN-only failure with a controlled test; inspect DNS, credentials, TLS, firewall, and relay allocation capacity.

## Safe mitigation

Restore TURN endpoint or credentials; scale relay capacity if measured saturation is the cause.

## Dangerous actions to avoid

Do not publish a static long-lived TURN credential or turn off authentication.

## Recovery validation

TURN-only client connects and sends/receives media; allocation errors return to baseline. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect region, carrier/network type, ICE logs without credentials, TURN node load, and certificate status. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
