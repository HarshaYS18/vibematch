"""Chunk 42 supply-chain policy guard."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    required = (
        ROOT / ".github/workflows/security-supply-chain.yml",
        ROOT / ".github/dependabot.yml",
        ROOT / "SECURITY.md",
        ROOT / "docs/security/supply-chain.md",
        ROOT / "docs/platform/chunk42-security-supply-chain.md",
    )
    for path in required:
        if not path.is_file():
            raise SystemExit(f"missing supply-chain file: {path.relative_to(ROOT)}")

    workflow = (ROOT / ".github/workflows/security-supply-chain.yml").read_text()
    for marker in ("dependency-review-action", "codeql-action", "gitleaks", "trivy-action"):
        if marker not in workflow:
            raise SystemExit(f"security workflow missing {marker}")

    secret_pattern = re.compile(
        r"(?i)(aws_secret_access_key|private_key|client_secret)\s*[:=]\s*['\"][A-Za-z0-9/+_=.-]{20,}"
    )
    offenders = []
    for base in (ROOT / "apps", ROOT / "backend", ROOT / "deploy"):
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".py", ".yaml", ".yml", ".json", ".toml"}:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if secret_pattern.search(text):
                offenders.append(str(path.relative_to(ROOT)))
    if offenders:
        raise SystemExit("possible committed secret material: " + ", ".join(offenders))

    print("Supply-chain policy guard: OK")


if __name__ == "__main__":
    main()
