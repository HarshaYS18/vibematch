"""Check repository-local Markdown links in architecture/operations docs."""

from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")

SCAN_ROOTS = (
    ROOT / "docs" / "developer-portal",
    ROOT / "docs" / "architecture",
    ROOT / "docs" / "runbooks",
    ROOT / "docs" / "governance",
)
SINGLE_FILES = (
    ROOT / "README.md",
    ROOT / "docs" / "MODULE_INDEX.md",
    ROOT / "docs" / "EXTERNAL_PREREQUISITES.md",
    ROOT / "frontend" / "vibematch_app" / "README.md",
)


def markdown_files() -> list[Path]:
    files: set[Path] = set(SINGLE_FILES)
    for root in SCAN_ROOTS:
        if root.is_dir():
            files.update(root.rglob("*.md"))
    return sorted(path for path in files if path.is_file())


def destination_path(source: Path, raw: str) -> Path | None:
    value = raw.strip()
    if not value or value.startswith(("#", "http://", "https://", "mailto:", "tel:", "sandbox:")):
        return None
    if value.startswith("<") and ">" in value:
        value = value[1:value.index(">")]
    else:
        value = value.split(maxsplit=1)[0]
    value = unquote(value.split("#", 1)[0].strip())
    if not value or "{" in value or "<" in value:
        return None
    if value.startswith("/"):
        return ROOT / value.lstrip("/")
    return (source.parent / value).resolve()


def main() -> None:
    broken: list[str] = []
    for source in markdown_files():
        text = source.read_text(encoding="utf-8", errors="replace")
        for raw in LINK_RE.findall(text):
            target = destination_path(source, raw)
            if target is None:
                continue
            try:
                target.relative_to(ROOT)
            except ValueError:
                broken.append(f"{source.relative_to(ROOT)} -> {raw} (escapes repository)")
                continue
            if not target.exists():
                broken.append(f"{source.relative_to(ROOT)} -> {raw}")
    if broken:
        raise SystemExit("Broken repository-local Markdown links:\n" + "\n".join(sorted(set(broken))))
    print(f"Documentation links: OK ({len(markdown_files())} Markdown files checked)")


if __name__ == "__main__":
    main()
