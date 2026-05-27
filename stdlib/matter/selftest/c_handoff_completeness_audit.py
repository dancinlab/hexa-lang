#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/c_handoff_completeness_audit.py — §C handoff completeness audit (gate #29).

Software cannot CLOSE Category (c) — wet-lab synthesis / vendor procurement /
fab capacity / regulatory pathway are out-of-software-scope by design (per
`AXIS_CLOSURE_PLAN.md` §0). But software CAN guarantee that the HANDOFF to
the external entity is documented honestly, completely, and audit-trail-clean.

For each §C row in `CLOSURE_RESIDUAL_BACKLOG.md`, this gate asserts:

  (a) The row has a non-empty DEST cell (a named vendor, lab, consortium,
      government program, or other external entity).
  (b) The row body mentions at least one of the canonical wall classifications
      from `LIMIT_BREAKTHROUGH.md` (HARD_WALL · SOFT_WALL · BREAKABLE_WITH_TECH
      · UNCLEAR · OUT-OF-SOFTWARE) OR an explicit `vendor` / `DEST:` token.
  (c) The row does NOT contain any n=6 lattice-fit pattern (rejects
      "fitted to n=6", "lattice-derived value", "lattice-fit applied", etc.)
      — raw#10 C3 enforcement.
  (d) The discovered §C row count matches the §D summary table claim.

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.

Emits on PASS:
  __HEXA_MATTER_C_HANDOFF__ PASS  (N/N items, 0 incomplete)
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

LEDGER = os.path.join(REPO_ROOT, "CLOSURE_RESIDUAL_BACKLOG.md")

# Canonical wall classifications (LIMIT_BREAKTHROUGH.md vocabulary)
WALL_TOKENS = (
    "HARD_WALL",
    "SOFT_WALL",
    "BREAKABLE_WITH_TECH",
    "BREAKABLE",
    "UNCLEAR",
    "OUT-OF-SOFTWARE",
    "OUT-OF-REPO",
)

# Honest-handoff tokens (any of these in the body counts as DEST-shape)
HANDOFF_TOKENS = ("vendor", "DEST:", "cross-domain")

# n=6 lattice-fit BAD patterns (raw#10 C3 violations).
# Each pattern matches a POSITIVE assertion of an n=6 lattice-fit. A
# leading negation token ("no", "not", "NO", "without") within ~15 chars
# flips the meaning into an honest disclaimer (e.g. "no lattice-fit applied")
# and is permitted — the row_has_n6_fit() check below applies a negation
# look-behind filter.
N6_FIT_PATTERNS = (
    re.compile(r"fit(ted)?\s+to\s+n\s*=\s*6", re.IGNORECASE),
    re.compile(r"n\s*=\s*6\s+lattice[-\s]?fit", re.IGNORECASE),
    re.compile(r"lattice[-\s]?derived\s+value", re.IGNORECASE),
    re.compile(r"lattice[-\s]?fit\s+applied", re.IGNORECASE),
    re.compile(r"χ²\s+(?:to|against)\s+lattice", re.IGNORECASE),
    re.compile(r"chi[-\s]?square\s+(?:to|against)\s+lattice", re.IGNORECASE),
)

NEGATION_RE = re.compile(r"\b(no|not|without|NO|never)\b", re.IGNORECASE)


def extract_section_c(text: str) -> str:
    m = re.search(
        r"^##\s+§C\b.*?(?=^##\s+§[A-Z]|^---\s*$)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not m:
        return ""
    return m.group(0)


def extract_c_rows(section_c: str) -> list[tuple[str, str]]:
    """Return list of (row_id, full_row_text) for every C-XXX-N row."""
    rows: list[tuple[str, str]] = []
    for line in section_c.splitlines():
        # Markdown table row beginning with | C-XXX-N |
        m = re.match(r"^\|\s*(C-[A-Z]{3}-\d+)\s*\|", line)
        if m:
            rows.append((m.group(1), line))
    return rows


def extract_summary_count(section_c: str) -> int | None:
    """Read the 'ALL N (c) items' Observation line — the §C-internal claim."""
    m = re.search(r"ALL\s+(\d+)\s+\(c\)\s+items", section_c)
    if m:
        return int(m.group(1))
    return None


def row_dest_nonempty(row_line: str) -> bool:
    """A row is `| ID | Item | DEST | wall |` — check DEST column is non-empty."""
    parts = [c.strip() for c in row_line.strip().strip("|").split("|")]
    if len(parts) < 3:
        return False
    return bool(parts[2])


def row_mentions_wall_or_dest(row_line: str) -> bool:
    body = row_line.lower()
    for tok in WALL_TOKENS:
        if tok.lower() in body:
            return True
    for tok in HANDOFF_TOKENS:
        if tok.lower() in body:
            return True
    return False


def row_has_n6_fit(row_line: str) -> bool:
    """Detect positive n=6 lattice-fit assertions; ignore honest disclaimers
    where the bad pattern is immediately preceded by a negation token
    ("no lattice-fit applied", "without n=6 fit", etc.).
    """
    for pat in N6_FIT_PATTERNS:
        for m in pat.finditer(row_line):
            window_start = max(0, m.start() - 20)
            window = row_line[window_start : m.start()]
            if NEGATION_RE.search(window):
                continue
            return True
    return False


def main() -> int:
    print("hexa-matter/selftest/c_handoff_completeness_audit — §C handoff completeness")
    print(f"  ledger: {LEDGER}\n")

    if not os.path.exists(LEDGER):
        print(f"  [FAIL] CLOSURE_RESIDUAL_BACKLOG.md not found at {LEDGER}")
        print("__HEXA_MATTER_C_HANDOFF__ FAIL  (ledger missing)")
        return 1

    with open(LEDGER, "r", encoding="utf-8") as fh:
        text = fh.read()

    section_c = extract_section_c(text)
    if not section_c:
        print("  [FAIL] §C section not found in ledger")
        print("__HEXA_MATTER_C_HANDOFF__ FAIL  (no §C)")
        return 1

    rows = extract_c_rows(section_c)
    n_rows = len(rows)
    print(f"  discovered §C rows: {n_rows}")
    for rid, _ in rows:
        print(f"    - {rid}")
    print()

    incomplete = 0
    fail = 0

    for rid, line in rows:
        problems: list[str] = []
        if not row_dest_nonempty(line):
            problems.append("empty DEST cell")
        if not row_mentions_wall_or_dest(line):
            problems.append("no wall/DEST token (HARD_WALL/SOFT_WALL/BREAKABLE/UNCLEAR/OUT-OF-SOFTWARE/vendor/DEST:)")
        if row_has_n6_fit(line):
            problems.append("n=6 lattice-fit pattern present (raw#10 C3 violation)")
        if problems:
            incomplete += 1
            fail += 1
            print(f"  [FAIL] {rid}: {'; '.join(problems)}")
        else:
            print(f"  [PASS] {rid}")

    # Count parity vs §C internal Observation claim
    summary_n = extract_summary_count(section_c)
    if summary_n is None:
        print("  [WARN] §C summary 'ALL N (c) items' line not found; skipping count parity")
    elif summary_n != n_rows:
        fail += 1
        print(f"  [FAIL] §C summary claims {summary_n} items but {n_rows} rows discovered")
    else:
        print(f"  [PASS] §C summary count {summary_n} matches discovered rows {n_rows}")

    print()
    if fail == 0 and n_rows > 0:
        print(f"__HEXA_MATTER_C_HANDOFF__ PASS  ({n_rows}/{n_rows} items, 0 incomplete)")
        return 0
    print(f"__HEXA_MATTER_C_HANDOFF__ FAIL  ({incomplete} incomplete of {n_rows} items, {fail} total failures)")
    return 1


if __name__ == "__main__":
    # Tolerate --selftest flag for uniform invocation
    if "--selftest" in sys.argv:
        sys.argv.remove("--selftest")
    raise SystemExit(main())
