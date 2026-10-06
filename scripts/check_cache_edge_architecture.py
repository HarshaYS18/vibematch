"""Chunk 47 cache/edge architecture guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    policy=json.loads((ROOT/"contracts/cache/cache-policy-v1.json").read_text())
    forbidden=" ".join(policy["forbidden"]).lower()
    for marker in ("wallet","authorization","session","settlement"):
        if marker not in forbidden: raise SystemExit(f"cache forbidden list missing {marker}")
    helper=(ROOT/"backend/app/core/cache_policy.py").read_text()
    for marker in ("nx=True","ttl",":lock","sha256","0.5"):
        if marker not in helper: raise SystemExit(f"cache stampede helper missing {marker}")
    docs=(ROOT/"docs/architecture/cache-edge.md").read_text()
    if "PostgreSQL" not in docs or "authority" not in docs.lower():
        raise SystemExit("cache docs must preserve authority")
    print("Cache/edge architecture guard: OK")
if __name__=="__main__": main()
