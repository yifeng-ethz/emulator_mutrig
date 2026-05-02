#!/usr/bin/env python3
"""Enforce per-page section template for the emulator_mutrig engineering wiki.

Every src/<NN>_*.md page must have these top-level Markdown headings in
order, and each section must be non-empty (at least one prose line):

    # <Page Title>
    ## TL;DR
    ## Why this exists
    ## How it works
    ## Interfaces and contracts
    ## Where to look in the code
    ## Open questions / gotchas

Usage:
    python3 lint_wiki.py <src-dir>

Exit 0 on success, 1 on any finding.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REQUIRED = (
    "TL;DR",
    "Why this exists",
    "How it works",
    "Interfaces and contracts",
    "Where to look in the code",
    "Open questions / gotchas",
)

H1_RE = re.compile(r"^#\s+(.+?)\s*$")
H2_RE = re.compile(r"^##\s+(.+?)\s*$")


def lint_page(path: Path) -> list[str]:
    findings: list[str] = []
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    # Title
    h1_idx = None
    for idx, line in enumerate(lines):
        if H1_RE.match(line):
            h1_idx = idx
            break
    if h1_idx is None:
        findings.append(f"{path}: missing top-level # title")
        return findings

    # Walk H2s in order, gather their bodies.
    h2_positions: list[tuple[str, int]] = []
    for idx, line in enumerate(lines):
        m = H2_RE.match(line)
        if m:
            h2_positions.append((m.group(1).strip(), idx))

    found = [name for name, _ in h2_positions]
    expected = list(REQUIRED)

    # Order check: every required heading must appear and in this exact order.
    cursor = 0
    order_ok = True
    for required in expected:
        try:
            cursor = found.index(required, cursor) + 1
        except ValueError:
            findings.append(f"{path}: missing or out-of-order section `## {required}`")
            order_ok = False

    if not order_ok:
        findings.append(f"{path}: page section order must be exactly {expected}")

    # Non-empty check: each required section must have at least one non-blank
    # non-heading line before the next heading.
    for i, (name, idx) in enumerate(h2_positions):
        if name not in REQUIRED:
            continue
        next_idx = h2_positions[i + 1][1] if i + 1 < len(h2_positions) else len(lines)
        body = [
            ln for ln in lines[idx + 1 : next_idx]
            if ln.strip() and not ln.strip().startswith("#")
        ]
        if not body:
            findings.append(f"{path}: section `## {name}` is empty")

    return findings


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: lint_wiki.py <src-dir>", file=sys.stderr)
        return 2
    src_dir = Path(argv[1])
    if not src_dir.is_dir():
        print(f"not a directory: {src_dir}", file=sys.stderr)
        return 2

    pages = sorted(src_dir.glob("*.md"))
    if not pages:
        print(f"no .md pages in {src_dir}", file=sys.stderr)
        return 2

    all_findings: list[str] = []
    for page in pages:
        all_findings.extend(lint_page(page))

    if all_findings:
        for f in all_findings:
            print(f"ERROR: {f}")
        print(f"\n{len(all_findings)} finding(s)")
        return 1
    print(f"OK — {len(pages)} pages lint-clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
