# Fraud / Economy integrity incident

Freeze only the affected operation/user scope using the owning domain's supported
hold/review control. Do not edit ledger rows by hand.

Collect risk reason codes, request/event IDs, Economy transaction IDs, settlement
IDs, device/account signals and moderation case references. Re-run reconciliation
before deciding whether the issue is fraud, duplicate delivery or a software
defect.

For suspected duplicate settlement, stop the relevant game/economy command path,
verify idempotency identities and compare authoritative ledger journals. Never
"fix" totals by inserting compensating records without an approved reconciliation
procedure.
