"""Chunk 50 SRE/FinOps/production-certification guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    slo=json.loads((ROOT/"contracts/sre/slo-v1.json").read_text())
    for name in ("room_join","wallet_mutation","inbox_send","realtime_event_propagation","media_join"):
        if name not in slo["slos"]: raise SystemExit(f"missing SLO: {name}")
    if slo["slos"]["wallet_mutation"].get("durable_loss") != 0:
        raise SystemExit("wallet durable loss objective must remain zero")
    finops=json.loads((ROOT/"contracts/sre/finops-unit-costs-v1.json").read_text())
    if len(finops["unit_metrics"]) < 8: raise SystemExit("FinOps unit cost coverage incomplete")
    plan=json.loads((ROOT/"contracts/sre/production-certification-plan-v1.json").read_text())
    for scenario in ("six_hour_soak","twenty_four_hour_soak","database_failover","redis_role_failure","nats_failover","kafka_failover","rollback_drill"):
        if scenario not in plan["required_scenarios"]: raise SystemExit(f"certification missing {scenario}")
    workflow=(ROOT/".github/workflows/production-certification.yml").read_text()
    if "production_certification.py" not in workflow:
        raise SystemExit("production certification workflow missing evidence validator")
    print("SRE/FinOps/certification guard: OK")
if __name__=="__main__": main()
