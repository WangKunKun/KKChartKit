#!/usr/bin/env python3
"""Validate chart documentation links and portable screenshot manifests.

No Xcode, Pillow, network access, or temporary xcresult directory is required.
This checks saved evidence integrity, not test execution or visual correctness.
"""
from pathlib import Path
import hashlib
import json
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
BATCHES = (
    "docs/evidence/charts-presentation-2026-10-02",
    "docs/evidence/charts-legacy-comparison/2026-10-02-g1-percent",
    "docs/evidence/charts-neutral-g1-2026-10-03/screenshots",
    "docs/evidence/charts-neutral-zones-2026-10-09/screenshots",
    "docs/evidence/charts-neutral-axes-2026-10-09/screenshots",
    "docs/evidence/charts-neutral-annotations-2026-10-09/screenshots",
    "docs/evidence/charts-neutral-interaction-2026-10-09/screenshots",
    "docs/evidence/charts-neutral-tooltip-layout-2026-10-09/screenshots",
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def documents(root):
    return sorted({root / "README.md", root / "README.en.md",
                   root / "Examples/ChartsIntegration/README.md",
                   *(root / "docs").glob("*chart*.md"),
                   *(root / "docs/evidence").rglob("README.md")})


def local_link_targets(text):
    """Read inline Markdown links used by chart docs, excluding fenced examples."""
    fence = None
    lines = []
    for line in text.splitlines():
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if marker:
            token = marker.group(1)
            if fence is None:
                fence = token
            elif token[0] == fence[0] and len(token) >= len(fence):
                fence = None
            continue
        if fence is None:
            lines.append(line)
    for match in re.finditer(r"\[[^\]\n]*\]\((<[^>\n]+>|[^)\n]+)\)", "\n".join(lines)):
        destination = match.group(1).strip()
        if destination.startswith("<"):
            destination = destination[1:-1]
        else:
            destination = re.sub(r'\s+["\'][^"\']*["\']$', "", destination)
        parts = urlsplit(destination)
        if parts.scheme or parts.netloc or not parts.path:
            continue
        # Codex file links may include a :line or :line:column suffix.
        yield re.sub(r":\d+(?::\d+)?$", "", unquote(parts.path))


def check_links(root):
    count = 0
    errors = []
    for path in documents(root):
        if not path.is_file():
            errors.append(f"Missing document: {path.relative_to(root)}")
            continue
        for target in local_link_targets(path.read_text()):
            count += 1
            if not (path.parent / target).exists():
                errors.append(f"Broken link: {path.relative_to(root)} -> {target}")
    return count, errors


def check_screenshots(directory):
    manifest = directory / "screenshots.json"
    errors = []
    try:
        entries = json.loads(manifest.read_text())
    except (OSError, ValueError) as error:
        return 0, [f"{manifest}: {error}"]
    if not isinstance(entries, list) or not entries:
        return 0, [f"{manifest}: expected a nonempty screenshot list"]
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            errors.append(f"{manifest}: screenshot entry must be an object")
            continue
        name = entry.get("file", "")
        if not isinstance(name, str) or not name or Path(name).name != name or not name.endswith(".png"):
            errors.append(f"{manifest}: invalid screenshot file {name!r}")
            continue
        if name in seen:
            errors.append(f"{manifest}: duplicate screenshot {name}")
        seen.add(name)
        path = directory / name
        if not path.is_file():
            errors.append(f"Missing screenshot: {path}")
            continue
        data = path.read_bytes()
        if not data.startswith(PNG_SIGNATURE):
            errors.append(f"Not a PNG: {path}")
        if hashlib.sha256(data).hexdigest() != entry.get("sha256"):
            errors.append(f"SHA-256 mismatch: {path}")
        if not entry.get("test") or not str(entry.get("resultBundle", "")).endswith(".xcresult"):
            errors.append(f"Missing test/result provenance: {path}")
        attachment = entry.get("attachment")
        if not isinstance(attachment, dict) or attachment.get("isAssociatedWithFailure") is not False:
            errors.append(f"Missing successful attachment provenance: {path}")
        elif not all(attachment.get(key) for key in ("deviceId", "exportedFileName", "suggestedHumanReadableName")):
            errors.append(f"Incomplete attachment provenance: {path}")
    unlisted = {p.name for p in directory.glob("*.png")} - seen
    errors.extend(f"Unlisted screenshot: {directory / name}" for name in sorted(unlisted))
    return len(entries), errors


def main():
    link_count, errors = check_links(ROOT)
    image_count = 0
    for batch in BATCHES:
        count, problems = check_screenshots(ROOT / batch)
        image_count += count
        errors.extend(problems)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"PASS: {len(documents(ROOT))} chart documents, {link_count} local links, "
          f"{image_count} original screenshots across {len(BATCHES)} current batches")
    print("Integrity only; XCTest execution and visual review are separate checks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
