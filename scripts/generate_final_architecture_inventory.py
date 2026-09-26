#!/usr/bin/env python3
"""Generate a non-secret final architecture inventory for review/CI evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TABLE_RE = re.compile(r'__tablename__\s*=\s*["\']([^"\']+)["\']')
ROUTE_RE = re.compile(r'@(?:router|app)\.(get|post|put|patch|delete|websocket)\(\s*["\']([^"\']+)["\']')
ENV_RE = re.compile(r'(?:os\.getenv|os\.environ\.get)\(\s*["\']([A-Z][A-Z0-9_]+)["\']')
ALERT_RE = re.compile(r'(?m)^\s*-?\s*alert:\s*([A-Za-z0-9_:-]+)\s*$')
SUBJECT_RE = re.compile(r'["\']((?:funkey|FUNKEY)[A-Za-z0-9_.>*:-]+)["\']')


def text_files(root: Path, suffixes: set[str]) -> list[Path]:
    return sorted(
        path for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in suffixes
        and ".git" not in path.parts
        and "build" not in path.parts
        and ".dart_tool" not in path.parts
    )


def dependencies() -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for path in sorted(ROOT.rglob("requirements*.txt")):
        if any(part in {".venv", "venv", "build"} for part in path.parts):
            continue
        values = []
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if line and not line.startswith(("#", "-")):
                values.append(line)
        result[str(path.relative_to(ROOT))] = values

    pubspec = ROOT / "frontend/vibematch_app/pubspec.yaml"
    if pubspec.is_file():
        direct = []
        in_dependencies = False
        for line in pubspec.read_text(encoding="utf-8").splitlines():
            if line == "dependencies:":
                in_dependencies = True
                continue
            if in_dependencies and line and not line.startswith("  "):
                break
            if in_dependencies:
                match = re.match(r"^  ([a-zA-Z0-9_]+):", line)
                if match and match.group(1) != "flutter":
                    direct.append(match.group(1))
        result[str(pubspec.relative_to(ROOT))] = direct

    package = ROOT / "backend_media/package.json"
    if package.is_file():
        payload = json.loads(package.read_text(encoding="utf-8"))
        result[str(package.relative_to(ROOT))] = sorted(
            set(payload.get("dependencies", {})) | set(payload.get("devDependencies", {}))
        )

    go_mod = ROOT / "apps/realtime-gateway/go.mod"
    if go_mod.is_file():
        result[str(go_mod.relative_to(ROOT))] = [
            line.strip() for line in go_mod.read_text(encoding="utf-8").splitlines()
            if line.strip().startswith("github.com/")
        ]
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    py = text_files(ROOT, {".py"})
    dart = text_files(ROOT / "frontend/vibematch_app/lib", {".dart"})
    yaml = text_files(ROOT / "deploy", {".yaml", ".yml"})

    tables: dict[str, str] = {}
    routes: list[dict[str, str]] = []
    env_vars: set[str] = set()
    subjects: set[str] = set()
    alerts: set[str] = set()
    websocket_sources: list[str] = []

    for path in py:
        text = path.read_text(encoding="utf-8", errors="replace")
        for table in TABLE_RE.findall(text):
            tables[table] = str(path.relative_to(ROOT))
        for method, route in ROUTE_RE.findall(text):
            routes.append({
                "method": method.upper(),
                "path": route,
                "source": str(path.relative_to(ROOT)),
            })
        env_vars.update(ENV_RE.findall(text))
        subjects.update(SUBJECT_RE.findall(text))

    for path in dart:
        text = path.read_text(encoding="utf-8", errors="replace")
        if any(marker in text for marker in (
            "web_socket_channel",
            "socket_io_client",
            "WebSocket.connect",
            "IOWebSocketChannel",
        )):
            websocket_sources.append(str(path.relative_to(ROOT)))

    for path in yaml:
        text = path.read_text(encoding="utf-8", errors="replace")
        alerts.update(ALERT_RE.findall(text))

    flags_path = ROOT / "backend/app/config/feature_flags_v1.json"
    flags = []
    if flags_path.is_file():
        flags = sorted(
            item["key"]
            for item in json.loads(flags_path.read_text(encoding="utf-8")).get("flags", [])
        )

    inventory = {
        "schema_version": 1,
        "database_tables": dict(sorted(tables.items())),
        "http_and_websocket_routes": sorted(routes, key=lambda row: (row["path"], row["method"], row["source"])),
        "frontend_socket_sources": sorted(websocket_sources),
        "event_subject_literals": sorted(subjects),
        "feature_flags": flags,
        "environment_variables_from_os_getenv": sorted(env_vars),
        "prometheus_alerts": sorted(alerts),
        "direct_dependencies": dependencies(),
        "notes": [
            "Inventory is structural evidence, not runtime reachability proof.",
            "Secret values are never collected.",
            "Production capacity/SLO compliance requires production-certification evidence."
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
