"""Chunk 52 CODEOWNERS/service-catalog/governance guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FIELDS={"service","technical_owner","business_owner","on_call","tier","repo_path","dashboard","slo","runbook","dependencies","data_class"}

def main():
    codeowners=ROOT/".github/CODEOWNERS"
    if not codeowners.is_file() or "@HarshaYS18" not in codeowners.read_text():
        raise SystemExit("CODEOWNERS missing repository owner")
    catalog=json.loads((ROOT/"catalog/services.json").read_text())
    services=catalog.get("services",[])
    if len(services) < 15: raise SystemExit("service catalog is incomplete")
    names=set()
    for item in services:
        missing=FIELDS-set(item)
        if missing: raise SystemExit(f"{item.get('service')}: catalog fields missing {sorted(missing)}")
        if item["service"] in names: raise SystemExit(f"duplicate catalog service {item['service']}")
        names.add(item["service"])
        if not (ROOT/item["repo_path"]).exists(): raise SystemExit(f"{item['service']}: repo path missing")
        if not (ROOT/item["runbook"]).is_file(): raise SystemExit(f"{item['service']}: runbook missing")
    for p in ("docs/governance/architecture-review.md","docs/governance/rfc-process.md","docs/templates/RFC.md",".github/PULL_REQUEST_TEMPLATE.md","docs/platform/chunk52-ownership-governance.md"):
        if not (ROOT/p).is_file(): raise SystemExit(f"governance artifact missing: {p}")
    print("Ownership/CODEOWNERS/governance guard: OK")
if __name__=="__main__": main()
