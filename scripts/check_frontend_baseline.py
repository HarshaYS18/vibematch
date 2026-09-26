from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "frontend" / "vibematch_app"
MANIFEST = APP / "tool" / "frontend_baseline_manifest.json"

REQUIRED_SCREENS = {
    "login",
    "onboarding",
    "home",
    "room",
    "room_sheets",
    "profile",
    "vibes",
    "inbox",
    "wallet",
    "store",
    "games",
    "control_center",
}


def fail(message: str) -> None:
    print(f"Frontend baseline check failed: {message}")
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-runtime-evidence",
        action="store_true",
        help="Require captured goldens and measured runtime metrics.",
    )
    args = parser.parse_args()

    if not MANIFEST.exists():
        fail(f"missing {MANIFEST.relative_to(ROOT)}")

    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if data.get("ui_contract") != "existing_funkey_ui_no_redesign":
        fail("unexpected ui_contract")

    reference = data.get("reference")
    if not isinstance(reference, dict):
        fail("missing baseline reference metadata")
    commit = str(reference.get("commit") or "")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        fail("reference commit must be a full Git SHA")
    if reference.get("phase") != "post_chunk_5_pre_chunk_6":
        fail("baseline reference phase must remain post_chunk_5_pre_chunk_6")

    screens = data.get("screens")
    if not isinstance(screens, list):
        fail("screens must be a list")

    ids = {str(item.get("id") or "") for item in screens if isinstance(item, dict)}
    missing = REQUIRED_SCREENS - ids
    if missing:
        fail(f"missing required screens: {sorted(missing)}")

    metrics = data.get("runtime_metrics")
    if not isinstance(metrics, dict) or not metrics:
        fail("runtime_metrics must be declared")

    if args.require_runtime_evidence:
        uncaptured: list[str] = []
        missing_files: list[str] = []
        for item in screens:
            if not isinstance(item, dict):
                continue
            screen_id = str(item.get("id") or "")
            if item.get("captured") is not True:
                uncaptured.append(screen_id)
            golden = str(item.get("golden") or "")
            if not golden or not (APP / golden).exists():
                missing_files.append(screen_id)

        unmeasured = [key for key, value in metrics.items() if value is None]
        if uncaptured:
            fail(f"uncaptured goldens: {sorted(uncaptured)}")
        if missing_files:
            fail(f"missing golden files: {sorted(missing_files)}")
        if unmeasured:
            fail(f"unmeasured runtime metrics: {sorted(unmeasured)}")

    print(
        "Frontend baseline check passed"
        + (" with runtime evidence." if args.require_runtime_evidence else ".")
    )


if __name__ == "__main__":
    main()
