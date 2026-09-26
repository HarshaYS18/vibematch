#!/usr/bin/env python3
"""Enforce Flutter dead-code, dependency, asset and platform hygiene.

The cleanup pass established an evidence-backed zero baseline. This guard keeps
new pure orphans, unused dependencies, dead bundled assets and unsupported
desktop runners from returning while preserving deliberate compatibility/test
artifacts.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "frontend" / "vibematch_app"
LIB = APP / "lib"
PUBSPEC = APP / "pubspec.yaml"

UNSUPPORTED_PLATFORM_DIRS = {"linux", "macos", "windows"}
APPROVED_UNREACHABLE_LIB_DART = {
    "lib/foundation/offline/offline_projection_store.dart": (
        "Chunk 46 offline projection policy component retained by focused tests/guard"
    ),
}

DIRECTIVE_RE = re.compile(r"(?ms)^\s*(import|export|part)\s+([^;]+);")
URI_RE = re.compile(r"['\"]([^'\"]+)['\"]")
ASSET_LITERAL_RE = re.compile(r"['\"](assets/[^'\"]+)['\"]")
PACKAGE_IMPORT_RE = re.compile(r"package:([A-Za-z0-9_]+)/")

def _norm(path: Path) -> Path:
    return Path(*path.parts)


def _resolve_uri(source: Path, uri: str) -> Path | None:
    if uri.startswith("dart:"):
        return None
    if uri.startswith("package:vibematch_app/"):
        return LIB / uri.removeprefix("package:vibematch_app/")
    if uri.startswith("package:"):
        return None
    return _norm((source.parent / uri).resolve())


def _dart_graph() -> tuple[dict[Path, set[Path]], dict[str, set[Path]], set[str], list[Path]]:
    graph: dict[Path, set[Path]] = defaultdict(set)
    packages: dict[str, set[Path]] = defaultdict(set)
    asset_literals: set[str] = set()
    roots: list[Path] = [LIB / "main.dart"]

    for source in LIB.rglob("*.dart"):
        text = source.read_text(encoding="utf-8-sig", errors="replace")
        if "@pragma('vm:entry-point')" in text or '@pragma("vm:entry-point")' in text:
            roots.append(source)

        for directive in DIRECTIVE_RE.finditer(text):
            kind, body = directive.groups()
            if kind == "part" and body.lstrip().startswith("of "):
                continue
            for uri in URI_RE.findall(body):
                package_match = PACKAGE_IMPORT_RE.match(uri)
                if package_match and package_match.group(1) != "vibematch_app":
                    packages[package_match.group(1)].add(source)
                    continue
                resolved = _resolve_uri(source, uri)
                if resolved is not None:
                    graph[source].add(resolved)

        asset_literals.update(ASSET_LITERAL_RE.findall(text))

    return graph, packages, asset_literals, roots


def _reachable(graph: dict[Path, set[Path]], roots: list[Path]) -> set[Path]:
    found: set[Path] = set()
    queue = deque(roots)
    while queue:
        current = queue.popleft()
        if current in found or not current.is_file():
            continue
        found.add(current)
        queue.extend(graph.get(current, ()))
    return found


def _pubspec_dependencies() -> tuple[set[str], list[str]]:
    lines = PUBSPEC.read_text(encoding="utf-8").splitlines()
    deps: set[str] = set()
    asset_prefixes: list[str] = []
    section: str | None = None
    for line in lines:
        if line and not line.startswith(" "):
            section = line.rstrip(":").strip()
            continue
        if section == "dependencies":
            match = re.match(r"^  ([A-Za-z0-9_]+):", line)
            if match and match.group(1) != "flutter":
                deps.add(match.group(1))
        if section == "flutter":
            match = re.match(r"^    - (assets/\S+)\s*$", line)
            if match:
                asset_prefixes.append(match.group(1))
    return deps, asset_prefixes


def _test_roots_and_package_imports(
    packages: dict[str, set[Path]],
) -> tuple[list[Path], dict[str, set[Path]]]:
    combined = {name: set(paths) for name, paths in packages.items()}
    roots: list[Path] = []
    for source in (APP / "test").rglob("*.dart"):
        text = source.read_text(encoding="utf-8-sig", errors="replace")
        for name in PACKAGE_IMPORT_RE.findall(text):
            if name != "vibematch_app":
                combined.setdefault(name, set()).add(source)
        for directive in DIRECTIVE_RE.finditer(text):
            kind, body = directive.groups()
            if kind == "part" and body.lstrip().startswith("of "):
                continue
            for uri in URI_RE.findall(body):
                resolved = _resolve_uri(source, uri)
                if resolved is not None and str(resolved).startswith(str(LIB)):
                    roots.append(resolved)
    return roots, combined


def _external_path_references(candidates: list[Path]) -> dict[Path, list[Path]]:
    references: dict[Path, list[Path]] = {candidate: [] for candidate in candidates}
    scan_roots = (
        ROOT / "scripts",
        ROOT / "docs",
        ROOT / "contracts",
        ROOT / ".github",
        APP / "test",
    )
    needles = {
        path: (
            path.relative_to(APP).as_posix(),
            path.relative_to(LIB).as_posix(),
            f"package:vibematch_app/{path.relative_to(LIB).as_posix()}",
        )
        for path in candidates
    }
    for scan_root in scan_roots:
        if not scan_root.exists():
            continue
        for source in scan_root.rglob("*"):
            if not source.is_file():
                continue
            try:
                text = source.read_text(encoding="utf-8-sig")
            except (UnicodeDecodeError, OSError):
                continue
            for candidate, values in needles.items():
                if any(value in text for value in values):
                    references[candidate].append(source)
    return {candidate: sources for candidate, sources in references.items() if sources}


def _asset_report(
    asset_literals: set[str], declared_prefixes: list[str]
) -> tuple[list[str], list[str], list[str], dict[str, list[str]]]:
    asset_files = sorted(
        path.relative_to(APP).as_posix()
        for path in (APP / "assets").rglob("*")
        if path.is_file()
    )
    unbundled = [
        asset for asset in asset_files
        if not any(asset.startswith(prefix) for prefix in declared_prefixes)
    ]

    dynamic_prefixes: set[str] = set()
    for source in LIB.rglob("*.dart"):
        text = source.read_text(encoding="utf-8-sig", errors="replace")
        for literal in ASSET_LITERAL_RE.findall(text):
            if "$" in literal or "{" in literal:
                prefix = re.split(r"[$\\{]", literal, maxsplit=1)[0]
                dynamic_prefixes.add(prefix)
            elif literal.endswith("/"):
                dynamic_prefixes.add(literal)

    literal_unreferenced = [
        asset for asset in asset_files
        if asset not in asset_literals
        and not any(asset.startswith(prefix) for prefix in dynamic_prefixes)
    ]

    external_refs: dict[str, list[str]] = {asset: [] for asset in literal_unreferenced}
    text_suffixes = {
        ".dart", ".yaml", ".yml", ".json", ".xml", ".plist", ".html",
        ".js", ".ts", ".gradle", ".kts", ".properties", ".md",
    }
    for source in ROOT.rglob("*"):
        if not source.is_file() or source.is_relative_to(APP / "assets"):
            continue
        if any(
            part in {
                ".dart_tool", "build", ".git", "node_modules", ".terraform",
                "__pycache__", ".venv", "venv",
            }
            for part in source.parts
        ):
            continue
        if source == PUBSPEC or source.suffix.lower() not in text_suffixes:
            continue
        try:
            text = source.read_text(encoding="utf-8-sig")
        except (UnicodeDecodeError, OSError):
            continue
        for asset in literal_unreferenced:
            if asset in text:
                external_refs[asset].append(source.relative_to(APP).as_posix())

    external_refs = {
        asset: refs for asset, refs in external_refs.items() if refs
    }
    return (
        unbundled,
        literal_unreferenced,
        sorted(dynamic_prefixes),
        external_refs,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail when unnecessary Flutter sources, dependencies or assets remain",
    )
    args = parser.parse_args()

    graph, packages, asset_literals, roots = _dart_graph()
    reachable = _reachable(graph, roots)
    lib_files = sorted(LIB.rglob("*.dart"))
    unreachable = [
        path.relative_to(APP).as_posix()
        for path in lib_files
        if path not in reachable
    ]

    dependencies, asset_prefixes = _pubspec_dependencies()
    runtime_imported_packages = {
        name
        for name, sources in packages.items()
        if any(source in reachable for source in sources)
    }
    test_roots, imported_packages = _test_roots_and_package_imports(packages)
    test_reachable = _reachable(graph, test_roots)
    external_refs = _external_path_references(
        [path for path in lib_files if path not in reachable]
    )
    pure_orphans = [
        path.relative_to(APP).as_posix()
        for path in lib_files
        if path not in reachable
        and path not in test_reachable
        and path not in external_refs
    ]
    unused_dependencies = sorted(dependencies - set(imported_packages))
    runtime_unused_dependencies = sorted(
        dependencies - runtime_imported_packages
    )
    (
        unbundled_assets,
        literal_unreferenced_assets,
        dynamic_asset_prefixes,
        external_asset_references,
    ) = _asset_report(asset_literals, asset_prefixes)

    asset_manifest_consumers: list[str] = []
    for source in LIB.rglob("*.dart"):
        text = source.read_text(encoding="utf-8-sig", errors="replace")
        if any(
            token in text
            for token in (
                "AssetManifest",
                "AssetManifest.json",
                "loadString('AssetManifest",
                'loadString("AssetManifest',
            )
        ):
            asset_manifest_consumers.append(source.relative_to(APP).as_posix())

    unexpected_unreachable = sorted(
        path for path in unreachable
        if path not in APPROVED_UNREACHABLE_LIB_DART
    )
    dead_bundled_assets = sorted(
        asset for asset in literal_unreferenced_assets
        if asset not in external_asset_references
    )
    present_unsupported_platforms = sorted(
        platform
        for platform in UNSUPPORTED_PLATFORM_DIRS
        if (APP / platform).exists()
    )

    asset_files = sorted(
        path.relative_to(APP).as_posix()
        for path in (APP / "assets").rglob("*")
        if path.is_file()
    )
    empty_dynamic_asset_prefixes = sorted(
        prefix
        for prefix in dynamic_asset_prefixes
        if not any(asset.startswith(prefix) for asset in asset_files)
    )
    empty_dynamic_asset_prefix_sources: dict[str, list[str]] = {}
    for prefix in empty_dynamic_asset_prefixes:
        sources: list[str] = []
        for source in LIB.rglob("*.dart"):
            text = source.read_text(encoding="utf-8-sig", errors="replace")
            if prefix in text:
                sources.append(source.relative_to(APP).as_posix())
        empty_dynamic_asset_prefix_sources[prefix] = sorted(sources)

    report = {
        "lib_dart_files": len(lib_files),
        "reachable_lib_dart_files": len(reachable),
        "unreachable_lib_dart": unreachable,
        "test_only_or_test_reachable_lib_dart": sorted(
            path.relative_to(APP).as_posix()
            for path in test_reachable
            if path not in reachable
        ),
        "externally_referenced_unreachable_lib_dart": sorted(
            path.relative_to(APP).as_posix() for path in external_refs
        ),
        "unreachable_reference_sources": {
            path.relative_to(APP).as_posix(): sorted(
                source.relative_to(ROOT).as_posix() for source in sources
            )
            for path, sources in sorted(
                external_refs.items(), key=lambda item: item[0].as_posix()
            )
        },
        "pure_orphan_lib_dart": pure_orphans,
        "approved_unreachable_lib_dart": {
            path: APPROVED_UNREACHABLE_LIB_DART[path]
            for path in sorted(APPROVED_UNREACHABLE_LIB_DART)
            if path in unreachable
        },
        "unexpected_unreachable_lib_dart": unexpected_unreachable,
        "direct_dependencies": sorted(dependencies),
        "runtime_imported_direct_dependencies": sorted(
            dependencies & runtime_imported_packages
        ),
        "imported_direct_dependencies": sorted(dependencies & set(imported_packages)),
        "unused_direct_dependencies": unused_dependencies,
        "runtime_unused_direct_dependencies": runtime_unused_dependencies,
        "unbundled_assets": unbundled_assets,
        "dynamic_asset_prefixes": dynamic_asset_prefixes,
        "empty_dynamic_asset_prefixes": empty_dynamic_asset_prefixes,
        "empty_dynamic_asset_prefix_sources": empty_dynamic_asset_prefix_sources,
        "asset_manifest_consumers": sorted(asset_manifest_consumers),
        "external_asset_references": external_asset_references,
        "literal_unreferenced_assets": literal_unreferenced_assets,
        "dead_bundled_assets": dead_bundled_assets,
        "unsupported_platform_directories": present_unsupported_platforms,
    }
    print(json.dumps(report, indent=2))

    if args.check:
        failures: list[str] = []
        if pure_orphans:
            failures.append(
                "pure orphan Dart files: " + ", ".join(pure_orphans)
            )
        if unexpected_unreachable:
            failures.append(
                "unexpected unreachable Dart files: "
                + ", ".join(unexpected_unreachable)
            )
        if unused_dependencies:
            failures.append(
                "unused direct dependencies: " + ", ".join(unused_dependencies)
            )
        if runtime_unused_dependencies:
            failures.append(
                "production dependencies unused by reachable runtime Dart: "
                + ", ".join(runtime_unused_dependencies)
            )
        if unbundled_assets:
            failures.append(
                "unbundled asset files: " + ", ".join(unbundled_assets)
            )
        if dead_bundled_assets:
            failures.append(
                "unreferenced bundled assets: " + ", ".join(dead_bundled_assets)
            )
        if empty_dynamic_asset_prefixes:
            failures.append(
                "dynamic asset prefixes with no bundled files: "
                + json.dumps(empty_dynamic_asset_prefix_sources, sort_keys=True)
            )
        if present_unsupported_platforms:
            failures.append(
                "unsupported Flutter platform runners: "
                + ", ".join(present_unsupported_platforms)
            )
        if failures:
            raise SystemExit(
                "Flutter hygiene audit FAILED:\n - " + "\n - ".join(failures)
            )
        print("Flutter hygiene audit: zero unnecessary sources/dependencies/assets/platforms")


if __name__ == "__main__":
    main()
