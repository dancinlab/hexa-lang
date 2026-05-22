#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/falsifier_wellformed_audit.py — Phase J.1 deepening gate #31.

For every `hxm-<class>-<target>-<NNN>` candidate in NOVEL.md, assert the
falsifier triple is well-formed:

  1. An `F-<TAG>-<N>` token appears somewhere in the candidate's section
     (regex `\\bF-[A-Z][A-Z0-9_-]*-[0-9]+\\b`).
  2. The same section contains at least one number-with-unit pair (quantitative
     evidence) drawn from a curated materials-science unit allowlist.
  3. An explicit FAIL boundary (`→ FAIL`) appears within ±5 lines of the F-tag.
  4. Status column is DESIGN (or an allowed SIM-* / SYNTH-ROUTE / UNVERIFIED /
     FALSIFIED tag). Any EXTERNAL-VERIFIED / VERIFIED row WITHOUT an explicit
     external-lab citation on the same row is rejected.

Per LATTICE_POLICY §1.2 / §1.3 / raw#10 C3 + SPEC_FIRST: structure-only check,
no measurement claim. UNPROVEN / UNVERIFIED stamps stay UNTOUCHED.

stdlib-only. Exit 0 PASS / 1 FAIL.

Sentinel: `__HEXA_MATTER_FALSIFIER_WELLFORMED__ PASS (N candidates, M wellformed,
K nonconforming)` on success (K == 0).
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

CAND_RE = re.compile(r"\bhxm-[a-z0-9]+-[a-zA-Z0-9_-]+-[0-9]{3}\b")
ROW_RE = re.compile(r"^\|\s*`(hxm-[a-zA-Z0-9_-]+)`\s*\|(.+)$")
# F-tag regex — task spec is `F-[A-Z][A-Z0-9_-]*-[0-9]+`. NOVEL.md also has
# `F-2D-*` (numeric-leading) for the §3.8 two-dimensional class; tuning the
# leading-character class to `[A-Z0-9]` covers current corpus state per the
# Phase J.1 directive ("tune the heuristics to fit current state").
FTAG_RE = re.compile(r"\bF-[A-Z0-9][A-Z0-9_-]*-[0-9]+\b")

# Number + unit allowlist (curated materials-science units).
_UNIT = (
    r"(?:mAh/g|GPa|MPa|S/cm|mS/cm|nm|μm|cm[²2]|°C|K|mV|V|h|ppm|Wh/L|"
    r"wt\s*%|%|kJ/mol|J/g|W/\(?m[·\*]?K\)?|F/g|pC/N|μW/\(?m[·\*]?K[²2]\)?|"
    r"dB|Jones|fJ/bit|sun|EUR|USD|kg/m[³3]|g/cm[³3]|MGOe|cycles?|"
    r"mol/g|mmol/g|μmol|μs|ms|ns|fs|atm|bar|Pa|T|H|Hz|GHz|MHz|kg|t|m|km|Å)"
)
NUM_UNIT_RE = re.compile(r"\d+(?:\.\d+)?\s*" + _UNIT)

ALLOWED_STATUS = {
    "DESIGN", "SIM-DFT", "SIM-MD", "SIM-NNP", "SIM-NNP-PROXY",
    "SYNTH-ROUTE", "UNVERIFIED", "FALSIFIED",
}
HARD_STATUS = {"EXTERNAL-VERIFIED", "VERIFIED"}
_CITATION_HINT_RE = re.compile(
    r"(sample[-\s]?ID|lab\s+citation|external\s+lab|DOI:|arxiv:|"
    r"NIST|CRC|ASM|ASTM|SEMI|TAPPI|ISO|GIA|AATCC)",
    re.IGNORECASE,
)


def read(p: str) -> str:
    with open(os.path.join(REPO_ROOT, p), "r", encoding="utf-8") as fh:
        return fh.read()


def parse_rows() -> list[dict]:
    text = read("NOVEL.md")
    lines = text.splitlines()
    rows: list[dict] = []
    for idx, line in enumerate(lines):
        m = ROW_RE.match(line)
        if not m:
            continue
        if "PLACEHOLDER" in line:
            continue
        cid = m.group(1)
        if not CAND_RE.fullmatch(cid):
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        if len(cells) < 5:
            continue
        rows.append({
            "id": cid,
            "line": idx,
            "row_text": line,
            "status": cells[3].strip().strip("`"),
            "falsifier": cells[4],
        })
    # Attach ±5-line neighborhood for each row.
    for r in rows:
        lo = max(0, r["line"] - 5)
        hi = min(len(lines), r["line"] + 6)
        r["_neighborhood"] = "\n".join(lines[lo:hi])
    return rows


def check_row(r: dict) -> tuple[bool, str]:
    row_text = r["row_text"]
    falsifier = r["falsifier"]
    status = r["status"]
    nbhd = r["_neighborhood"]

    # (1) F-tag must exist in row OR neighborhood.
    if not (FTAG_RE.search(row_text) or FTAG_RE.search(nbhd)):
        return False, "missing F-tag in falsifier section"

    # (2) Quantitative number+unit pair in row OR neighborhood.
    if not (NUM_UNIT_RE.search(row_text) or NUM_UNIT_RE.search(nbhd)):
        return False, "missing number+unit pair (quantitative evidence)"

    # (3) Explicit FAIL boundary within ±5 lines of F-tag (use neighborhood).
    if "→ FAIL" not in nbhd and "→ FALSIFIED" not in nbhd:
        return False, "missing '→ FAIL' boundary within 5 lines of F-tag"

    # (4) Status whitelist + external citation guard.
    if status in HARD_STATUS and not _CITATION_HINT_RE.search(row_text):
        return False, f"status '{status}' without external-lab citation on row"
    if status not in ALLOWED_STATUS and status not in HARD_STATUS:
        # Status is something else — only allow if it looks like a known
        # bridge-state token. Otherwise reject.
        return False, f"unknown status '{status}' (not in DESIGN/SIM-*/SYNTH-ROUTE/UNVERIFIED/FALSIFIED)"

    return True, "wellformed"


def selftest() -> int:
    rows = parse_rows()
    assert len(rows) >= 100, f"expected ≥100 candidates, got {len(rows)}"
    assert CAND_RE.search("hxm-sc-cuprate-001"), "candidate regex broken"
    assert FTAG_RE.search("F-CATH-1"), "F-tag regex broken"
    assert NUM_UNIT_RE.search("3.6 GPa"), "num+unit regex broken"
    assert NUM_UNIT_RE.search("10 mAh/g"), "num+unit regex broken"
    assert "→ FAIL" in "x → FAIL y", "boundary literal broken"
    print("falsifier_wellformed_audit --selftest PASS")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()

    rows = parse_rows()
    print("hexa-matter/selftest/falsifier_wellformed_audit — Phase J.1 gate #31")
    print(f"  root: {REPO_ROOT}")
    print(f"  candidates: {len(rows)}\n")

    nonconforming: list[tuple[str, str]] = []
    wellformed = 0
    for r in rows:
        ok, msg = check_row(r)
        if ok:
            wellformed += 1
        else:
            nonconforming.append((r["id"], msg))

    if nonconforming:
        print(f"[FAIL] {len(nonconforming)} nonconforming candidate row(s):")
        for cid, msg in nonconforming[:25]:
            print(f"  - {cid}: {msg}")
        if len(nonconforming) > 25:
            print(f"  ... +{len(nonconforming) - 25} more")
    else:
        print(f"[PASS] all {wellformed} candidate rows wellformed")

    n = len(rows)
    k = len(nonconforming)
    if k:
        print(f"\n__HEXA_MATTER_FALSIFIER_WELLFORMED__ FAIL "
              f"({n} candidates, {wellformed} wellformed, {k} nonconforming)")
        return 1
    print(f"\n__HEXA_MATTER_FALSIFIER_WELLFORMED__ PASS "
          f"({n} candidates, {wellformed} wellformed, {k} nonconforming)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
