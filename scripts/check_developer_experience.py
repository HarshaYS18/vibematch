"""Chunk 53 developer-experience/golden-path guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    manifest=json.loads((ROOT/"dev/seed/seed-v1.json").read_text())
    for key in ("users","room","conversation","family","game","event_id"):
        if key not in manifest: raise SystemExit(f"dev seed manifest missing {key}")
    seed=(ROOT/"scripts/seed_dev.py").read_text()
    for marker in ("FUNKEY_DEV_SEED_CONFIRM","ALLOWED_ENVS","coin_balance=0","published_at=now"):
        if marker not in seed: raise SystemExit(f"seed safety missing {marker}")
    scaffold=(ROOT/"scripts/scaffold_service.py").read_text()
    for marker in ("/live","/ready","/metrics","Dockerfile","CODEOWNERS","runbooks"):
        if marker not in scaffold: raise SystemExit(f"service scaffold missing {marker}")
    task=(ROOT/"scripts/task.ps1").read_text()
    for task_name in ("bootstrap","seed","scaffold-service"):
        if task_name not in task: raise SystemExit(f"task runner missing {task_name}")
    make=(ROOT/"Makefile").read_text()
    for target in ("bootstrap","seed","scaffold-service"):
        if target not in make: raise SystemExit(f"Makefile missing {target}")
    if not (ROOT/"docs/developer-experience/golden-path.md").is_file():
        raise SystemExit("developer golden-path doc missing")
    print("Developer experience/golden-path guard: OK")
if __name__=="__main__": main()
