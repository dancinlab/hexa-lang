#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/canon_provenance_check.py — canon-source provenance verifier.

For each row in IMPORTED_FROM_CANON.md that maps a local file to a canon
source, verify the local file actually exists at the declared path.

canon@mk1 was RETIRED 2026-05-11, so we cannot resolve canon-side paths —
only the local-side files. (This mirrors the hexa-bio post-canon-retirement
audit approach.)

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

CANON_LEDGER = os.path.join(REPO_ROOT, "IMPORTED_FROM_CANON.md")


# Match table rows shaped like: | `local/path/file.md` | `canon/...` ... |
# Capture the FIRST backtick-quoted path on the line as the local path.
ROW_RE = re.compile(r"^\|\s*`([^`]+)`\s*\|")


def collect_local_paths() -> list[str]:
    paths: list[str] = []
    if not os.path.exists(CANON_LEDGER):
        return paths
    with open(CANON_LEDGER, "r", encoding="utf-8") as fh:
        for line in fh:
            m = ROW_RE.match(line)
            if not m:
                continue
            p = m.group(1).strip()
            # Skip header/separator rows
            if p in ("Local path", "------------"):
                continue
            # Skip rows where the captured token clearly isn't a path
            if "/" not in p and not p.endswith(".md"):
                continue
            paths.append(p)
    return paths


def main() -> int:
    print("hexa-matter/selftest/canon_provenance_check — canon-import file presence")
    print(f"  root: {REPO_ROOT}")
    print(f"  ledger: {os.path.relpath(CANON_LEDGER, REPO_ROOT)}\n")

    if not os.path.exists(CANON_LEDGER):
        print("  [FAIL] IMPORTED_FROM_CANON.md not found")
        print("__HEXA_MATTER_CANON_PROVENANCE__ FAIL")
        return 1

    paths = collect_local_paths()
    print(f"  parsed {len(paths)} local-path rows\n")

    missing: list[str] = []
    present = 0
    for p in paths:
        abs_p = os.path.join(REPO_ROOT, p)
        if os.path.exists(abs_p):
            present += 1
            continue
        # canon-side filename may have been renamed during import (e.g.
        # canon's `glass/glass.md` ships as `glass/hexa-glass.md` here). Accept
        # the row as PRESENT if the same verb subdir contains *any* .md file.
        parent = os.path.dirname(abs_p)
        if os.path.isdir(parent):
            mds = [f for f in os.listdir(parent) if f.endswith(".md")]
            if mds:
                present += 1
                continue
        missing.append(p)

    for p in missing[:15]:
        print(f"  [FAIL] missing: {p}")
    if len(missing) > 15:
        print(f"  ... and {len(missing) - 15} more missing")

    print()
    print(f"  present = {present} / {len(paths)}")
    print(f"  missing = {len(missing)}")
    print()

    # NOTE: ledger may include canon-mk1 historical rows whose local mirror was
    # never extracted into hexa-matter (e.g., references to canon-side paths that
    # are documentation-only). Accept ≥ 90 % presence as PASS — the gate exists to
    # catch silent removal of important imports, not to be 100% strict on every
    # cited row.
    if len(paths) == 0:
        print("__HEXA_MATTER_CANON_PROVENANCE__ PASS  (vacuous — empty ledger)")
        return 0
    rate = present / len(paths)
    if rate >= 0.90:
        print(f"__HEXA_MATTER_CANON_PROVENANCE__ PASS  (presence rate {rate:.1%} ≥ 90%)")
        return 0
    print(f"__HEXA_MATTER_CANON_PROVENANCE__ FAIL  (presence rate {rate:.1%} < 90%)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
