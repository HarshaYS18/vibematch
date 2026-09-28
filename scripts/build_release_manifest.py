#!/usr/bin/env python3
"""Build a reproducible FunKey deployment release manifest."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMAGE_RE = re.compile(r"^(?P<service>[a-z0-9-]+)=(?P<ref>[^\s@]+@sha256:[0-9a-f]{64})$")
EXPECTED_IMAGES = {
    "api",
    "inbox",
    "vibes",
    "room-control",
    "identity",
    "profile-social",
    "economy",
    "game-platform",
    "notification",
    "graphql-bff",
    "worker",
    "kafka-event-bridge",
    "search",
    "recommendation",
    "analytics-sink",
    "realtime",
    "media",
}


def git_sha(explicit: str | None) -> str:
    value = (explicit or "").strip().lower()
    if not value:
        value = subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            text=True,
        ).strip().lower()
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise SystemExit("git sha must be exactly 40 lowercase/uppercase hex characters")
    return value


def mobile_version(explicit: str | None) -> str:
    if explicit and explicit.strip():
        return explicit.strip()
    pubspec = (ROOT / "frontend/vibematch_app/pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"(?m)^version:\s*([^\s]+)\s*$", pubspec)
    if not match:
        raise SystemExit("Flutter version not found in pubspec.yaml")
    return match.group(1)


def parse_images(values: list[str]) -> dict[str, str]:
    images: dict[str, str] = {}
    for value in values:
        match = IMAGE_RE.fullmatch(value.strip())
        if not match:
            raise SystemExit(
                "--image must be service=name@sha256:<64 hex>, got " + repr(value)
            )
        service = match.group("service")
        if service in images:
            raise SystemExit(f"duplicate image service: {service}")
        images[service] = match.group("ref")
    missing = EXPECTED_IMAGES - set(images)
    extra = set(images) - EXPECTED_IMAGES
    if missing or extra:
        raise SystemExit(
            f"release images mismatch; missing={sorted(missing)} extra={sorted(extra)}"
        )
    return dict(sorted(images.items()))


def contract_snapshot() -> dict[str, object]:
    matrix = json.loads(
        (ROOT / "contracts/compatibility/version-matrix-v1.json").read_text(
            encoding="utf-8"
        )
    )
    contracts = matrix["server_contracts"]
    return {
        "rest": contracts["rest"]["current"],
        "realtime_envelope": contracts["realtime_envelope"]["current"],
        "graphql_persisted_operations": contracts["graphql_persisted_operations"]["current"],
        "game_bridge": contracts["game_bridge"]["current"],
        "asset_manifest": contracts["asset_manifest"]["current"],
    }


def feature_flag_snapshot() -> dict[str, object]:
    payload = json.loads(
        (ROOT / "backend/app/config/feature_flags_v1.json").read_text(
            encoding="utf-8"
        )
    )
    return {
        item["key"]: {
            "default": item["default"],
            "kill_switch": item["kill_switch"],
            "rollout_percentage": item["rollout_percentage"],
        }
        for item in sorted(payload["flags"], key=lambda item: item["key"])
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-version", required=True)
    parser.add_argument("--git-sha")
    parser.add_argument("--mobile-version")
    parser.add_argument("--migration-head", required=True)
    parser.add_argument("--rollback-target", required=True)
    parser.add_argument("--image", action="append", default=[], required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    release = args.release_version.strip()
    output = args.output or ROOT / "releases" / f"{release}.json"
    payload = {
        "schema_version": 1,
        "release_version": release,
        "git_sha": git_sha(args.git_sha),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mobile_version": mobile_version(args.mobile_version),
        "migration_head": args.migration_head.strip(),
        "contracts": contract_snapshot(),
        "feature_flags": feature_flag_snapshot(),
        "images": parse_images(args.image),
        "rollback_target": args.rollback_target.strip(),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
