"""Chunk 56 decommissioning registry guard."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "contracts/decommission/decommission-registry-v1.json"


def _matches(path_text: str) -> list[Path]:
    path = ROOT / path_text
    if path_text.endswith("/"):
        if not path.exists():
            return []
        return [p for p in path.rglob("*") if p.is_file()]
    return [path] if path.exists() else []


def main() -> None:
    if not REGISTRY.is_file():
        raise SystemExit("decommission registry missing")
    payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if payload.get("schema_version") != 1:
        raise SystemExit("unsupported decommission registry schema")

    for item in payload.get("removed", []):
        paths = item.get("paths") or []
        if not paths or not item.get("replacement") or not item.get("evidence"):
            raise SystemExit(f"invalid removed registry entry: {item.get('id')}")
        for path_text in paths:
            remaining = _matches(path_text)
            if remaining:
                names = ", ".join(str(p.relative_to(ROOT)) for p in remaining[:10])
                raise SystemExit(
                    f"decommissioned path still exists ({item.get('id')}): {names}"
                )

    for item in payload.get("retained_compatibility", []):
        path_text = item.get("path")
        if not path_text:
            raise SystemExit(f"retained entry lacks path: {item.get('id')}")
        path = ROOT / path_text
        if not path.exists():
            raise SystemExit(
                f"retained compatibility path disappeared without registry update: {path_text}"
            )
        for field in ("status", "reason", "removal_condition"):
            if not str(item.get(field) or "").strip():
                raise SystemExit(
                    f"retained entry {item.get('id')} lacks {field}"
                )

    api_alias = ROOT / "frontend/vibematch_app/lib/core/network/api_client.dart"
    alias_text = api_alias.read_text(encoding="utf-8")
    for forbidden in ("package:http/http.dart", "HttpClient(", "Dio("):
        if forbidden in alias_text:
            raise SystemExit(
                "deprecated ApiClient alias regained transport ownership: " + forbidden
            )
    if "DioAppNetworkClient" not in alias_text:
        raise SystemExit("deprecated ApiClient must delegate to canonical networking")

    legacy_snapshot = (ROOT / "backend/legacy_snapshot.py").read_text(encoding="utf-8")
    if "Frozen schema bridge" not in legacy_snapshot or "Alembic" not in legacy_snapshot:
        raise SystemExit("legacy_snapshot.py must remain a migration-only bridge")

    print("Decommissioning registry guard: OK")


if __name__ == "__main__":
    main()
