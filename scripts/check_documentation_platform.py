"""Chunk 51 documentation-platform guard."""
from __future__ import annotations
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

REQUIRED_SECTIONS=(
    "## Ownership","## Purpose","## Explicit non-responsibilities",
    "## Authority and durable state","## APIs and contracts","## Dependencies",
    "## Security and privacy","## Retry and idempotency","## Scaling and limits",
    "## SLO and observability","## Failure modes and runbook",
    "## Local development and testing","## Deployment / migration / rollback",
    "## Feature flags and compatibility","## Status",
)

def main():
    for path in (
        ROOT/"mkdocs.yml",
        ROOT/"docs/developer-portal/index.md",
        ROOT/"docs/templates/service-readme.md",
        ROOT/"frontend/vibematch_app/README.md",
        ROOT/"docs/platform/chunk51-documentation-platform.md",
    ):
        if not path.is_file(): raise SystemExit(f"missing documentation-platform artifact: {path.relative_to(ROOT)}")
    template=(ROOT/"docs/templates/service-readme.md").read_text()
    for section in REQUIRED_SECTIONS:
        if section not in template: raise SystemExit(f"service README template missing {section}")
    flutter=(ROOT/"frontend/vibematch_app/README.md").read_text()
    for marker in ("RoomSessionRepository","CanonicalNetworkTransport","one application WebSocket","Remote games","offline projection"):
        if marker not in flutter: raise SystemExit(f"Flutter architecture guide missing {marker}")
    print("Documentation platform guard: OK")
if __name__=="__main__": main()
