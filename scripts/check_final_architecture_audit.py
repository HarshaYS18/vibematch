"""Chunk 56 final architecture/decommission/dependency-hygiene guard."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

COMPOSED_GUARDS = (
    "check_backend_architecture.py",
    "check_frontend_architecture.py",
    "check_contracts.py",
    "check_gateway_architecture.py",
    "check_graphql_bff_architecture.py",
    "check_kafka_data_platform.py",
    "check_search_platform.py",
    "check_recommendation_platform.py",
    "check_multiregion_architecture.py",
    "check_disaster_recovery.py",
    "check_supply_chain.py",
    "check_privacy_governance.py",
    "check_trust_safety_integrity.py",
    "check_realtime_media_qos.py",
    "check_mobile_runtime.py",
    "check_cache_edge_architecture.py",
    "check_analytics_platform.py",
    "check_release_safety.py",
    "check_sre_finops.py",
    "check_documentation_platform.py",
    "check_ownership_governance.py",
    "check_developer_experience.py",
    "check_release_management.py",
    "check_architecture_conformance.py",
    "check_roadmap_closure.py",
)


def run_guard(name: str) -> None:
    path = ROOT / "scripts" / name
    if not path.is_file():
        raise SystemExit(f"missing final composed guard: {name}")
    result = subprocess.run([sys.executable, str(path)], cwd=ROOT, check=False)
    if result.returncode:
        raise SystemExit(f"final composed guard failed: {name}")


def check_decommission_registry() -> None:
    path = ROOT / "contracts/decommission/decommission-registry-v1.json"
    payload = json.loads(path.read_text(encoding="utf-8"))

    for item in payload["removed"]:
        for raw in item["paths"]:
            target = ROOT / raw
            if raw.endswith("/"):
                if target.exists():
                    raise SystemExit(f"decommissioned directory still exists: {raw}")
            elif target.exists():
                raise SystemExit(f"decommissioned file still exists: {raw}")

    for item in payload["retained_compatibility"]:
        if not (ROOT / item["path"]).exists():
            raise SystemExit(
                f"retained compatibility path disappeared without registry migration: {item['path']}"
            )


def check_legacy_snapshot_scope() -> None:
    offenders: list[str] = []
    migration_tooling = {
        ROOT / "backend/check_migrations.py",
    }
    for path in (ROOT / "backend").rglob("*.py"):
        if (
            path.name == "legacy_snapshot.py"
            or "alembic" in path.parts
            or path in migration_tooling
        ):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if "legacy_snapshot" in text:
            offenders.append(str(path.relative_to(ROOT)))
    if offenders:
        raise SystemExit(
            "legacy_snapshot is migration-only but leaked into runtime/test code: "
            + ", ".join(sorted(offenders))
        )


def check_flutter_legacy_paths() -> None:
    flutter = ROOT / "frontend/vibematch_app"
    pubspec = (flutter / "pubspec.yaml").read_text(encoding="utf-8")
    if "assets/games/" in pubspec:
        raise SystemExit("bundled game assets are forbidden; use verified CDN game runtime")

    kotlin = flutter / "android/app/src/main/kotlin"
    for path in kotlin.rglob("*.kt"):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "package com.example.vibematch_app" in text:
            raise SystemExit(f"obsolete Android package remains: {path.relative_to(ROOT)}")

    alias = flutter / "lib/core/network/api_client.dart"
    alias_rel = "core/network/api_client.dart"
    import_offenders: list[str] = []
    for path in (flutter / "lib").rglob("*.dart"):
        if path == alias:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if "core/network/api_client.dart" in text or "../core/network/api_client.dart" in text:
            import_offenders.append(str(path.relative_to(ROOT)))
    if import_offenders:
        raise SystemExit(
            "deprecated ApiClient alias still imported by supported sources: "
            + ", ".join(sorted(import_offenders))
        )

    # The alias may stay through the source-compatibility window, but it must be
    # a pure delegate and never regain transport ownership.
    alias_text = alias.read_text(encoding="utf-8")
    for forbidden in ("Dio(", "http.Client(", "WebSocket", "HttpClient("):
        if forbidden in alias_text:
            raise SystemExit(f"deprecated ApiClient alias regained transport ownership: {forbidden}")


def check_dependency_hygiene() -> None:
    dependabot = ROOT / ".github/dependabot.yml"
    if not dependabot.is_file():
        raise SystemExit("controlled Dependabot configuration is missing")
    text = dependabot.read_text(encoding="utf-8")
    for ecosystem in ("pip", "npm", "pub", "gomod", "github-actions", "terraform"):
        if f'package-ecosystem: "{ecosystem}"' not in text:
            raise SystemExit(f"dependency hygiene missing ecosystem: {ecosystem}")
    if "version-update:semver-major" not in text:
        raise SystemExit("major dependency updates must remain explicitly review-gated")


def main() -> None:
    check_decommission_registry()
    check_legacy_snapshot_scope()
    check_flutter_legacy_paths()
    check_dependency_hygiene()
    for guard in COMPOSED_GUARDS:
        run_guard(guard)
    print("Final architecture/decommission audit: OK")


if __name__ == "__main__":
    main()
