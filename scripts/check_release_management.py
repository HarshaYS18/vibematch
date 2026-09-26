"""Chunk 55 release-manifest/change-management guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    schema=json.loads((ROOT/"contracts/release/release-manifest-v1.schema.json").read_text())
    required=set(schema["required"])
    for key in ("release_version","git_sha","mobile_version","migration_head","contracts","feature_flags","images","rollback_target"):
        if key not in required: raise SystemExit(f"release schema missing {key}")
    builder=(ROOT/"scripts/build_release_manifest.py").read_text()
    for marker in ("EXPECTED_IMAGES","sha256","migration-head","rollback-target","feature_flag_snapshot","contract_snapshot"):
        if marker not in builder: raise SystemExit(f"release builder missing {marker}")
    for p in (
        "CHANGELOG.md",
        "releases/README.md",
        "docs/templates/engineering-release-notes.md",
        "docs/templates/user-release-notes.md",
        "docs/release/compatibility-matrix.md",
        "docs/platform/chunk55-release-management.md",
    ):
        if not (ROOT/p).is_file(): raise SystemExit(f"release-management artifact missing: {p}")
    print("Release/change-management guard: OK")
if __name__=="__main__": main()
