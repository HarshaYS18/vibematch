#!/usr/bin/env python3
"""Pin immutable backend images into a GitOps environment overlay."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

_IMAGE_KEYS = ("api", "worker", "realtime", "media")
_IMAGE_NAMES = {key: f"funkey-{key}" for key in _IMAGE_KEYS}
_REF_RE = re.compile(r"^(?P<name>[^\s@]+)@(?P<digest>sha256:[0-9a-fA-F]{64})$")


def parse_ref(value: str) -> tuple[str, str]:
    match = _REF_RE.fullmatch(value.strip())
    if not match:
        raise SystemExit(f"Image must be an immutable name@sha256:<64 hex> reference: {value!r}")
    digest = match.group("digest").lower()
    if digest == "sha256:" + ("0" * 64):
        raise SystemExit("Zero/sentinel image digests cannot be promoted")
    return match.group("name"), digest


def render_images(refs: dict[str, str]) -> str:
    lines = ["images:"]
    for key in _IMAGE_KEYS:
        name, digest = parse_ref(refs[key])
        lines.extend(
            [
                f"  - name: {_IMAGE_NAMES[key]}",
                f"    newName: {name}",
                f"    digest: {digest}",
            ]
        )
    return "\n".join(lines) + "\n"


def replace_images_block(text: str, replacement: str) -> str:
    marker = re.search(r"(?ms)^images:\n(?:^  .+\n|^    .+\n)*", text)
    if marker:
        return text[: marker.start()] + replacement + text[marker.end() :]
    if not text.endswith("\n"):
        text += "\n"
    return text + replacement


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", choices=("staging", "production"), required=True)
    for key in _IMAGE_KEYS:
        parser.add_argument(f"--{key}", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    path = root / "deploy" / "kubernetes" / "overlays" / args.environment / "kustomization.yaml"
    refs = {key: getattr(args, key) for key in _IMAGE_KEYS}
    path.write_text(replace_images_block(path.read_text(), render_images(refs)))
    print(path)


if __name__ == "__main__":
    main()
