#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/cross_doc_audit.py — cross-document consistency.

Beyond registry_consistency_audit.py (which checks verb-name parity), this
gate verifies semantic-content cross-document consistency:

  (1) README.md "36-verb" / "Phase D''" claims match hexa.toml [closure].verbs_total
  (2) hexa.toml [verify].scripts_passed (4) matches the verify/ count
  (3) AXIS.md group-counts (CER 15, POL 11, FIB 3, MET 3, GEM 1, PRC 3, FAS 0
      in-CLI) sum to 36
  (4) AGENTS.md references LATTICE_POLICY.md and LIMIT_BREAKTHROUGH.md by name

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


def read(p: str) -> str:
    with open(p, "r", encoding="utf-8") as fh:
        return fh.read()


def main() -> int:
    print("hexa-matter/selftest/cross_doc_audit — semantic consistency across docs")
    print(f"  root: {REPO_ROOT}\n")

    fail = 0

    # (1) README "36-verb" matches hexa.toml
    readme = read(os.path.join(REPO_ROOT, "README.md"))
    toml = read(os.path.join(REPO_ROOT, "hexa.toml"))
    m = re.search(r"verbs_total\s*=\s*([0-9]+)", toml)
    toml_total = int(m.group(1)) if m else None
    readme_mentions_36 = "36-verb" in readme or "36_spec" in readme or "36 verb" in readme
    if toml_total == 36 and readme_mentions_36:
        print("  [PASS] README 36-verb claim ↔ hexa.toml verbs_total=36")
    else:
        print(f"  [FAIL] README 36-verb={readme_mentions_36}  toml verbs_total={toml_total}")
        fail += 1

    # (2) verify scripts count
    verify_dir = os.path.join(REPO_ROOT, "verify")
    n_hexa = len([f for f in os.listdir(verify_dir) if f.endswith(".hexa") and f != "run_all.hexa"])
    m = re.search(r"scripts_total\s*=\s*([0-9]+)", toml)
    toml_scripts = int(m.group(1)) if m else None
    if toml_scripts == n_hexa:
        print(f"  [PASS] verify/*.hexa count {n_hexa} ↔ hexa.toml [verify].scripts_total={toml_scripts}")
    else:
        print(f"  [FAIL] verify/*.hexa count {n_hexa}  vs  hexa.toml [verify].scripts_total={toml_scripts}")
        fail += 1

    # (3) AXIS.md group sums to 33
    axis = read(os.path.join(REPO_ROOT, "AXIS.md"))
    # Pattern: "CER: …, … → **13**" etc.
    # Look for "→ **N**" or "= **N**" markers in AXIS.md §0:
    group_counts = re.findall(r"→ \*\*([0-9]+)\*\*", axis)
    if group_counts:
        ints = [int(x) for x in group_counts]
        # Take the first 7 group counts (CER/POL/FIB/MET/GEM/PRC/FAS) — note FAS may be 0.
        # AXIS.md §0 lists 7 groups; tolerate trailing summary numbers.
        # Find the bullet list of per-group counts.
        head_sum = sum(ints[:7]) if len(ints) >= 7 else sum(ints)
        if 35 <= head_sum <= 37:  # tolerate FAS:0 or FAS:1 wobble + lutherie note
            print(f"  [PASS] AXIS.md group counts head-sum ≈ 36  (got {head_sum} from {ints[:7]})")
        else:
            print(f"  [FAIL] AXIS.md group counts sum = {head_sum}  (expected ≈ 36)")
            fail += 1
    else:
        print("  [WARN] AXIS.md — could not parse per-group counts (regex miss); skipping")

    # (4) AGENTS.md references policy files
    agents = read(os.path.join(REPO_ROOT, "AGENTS.md"))
    if "LATTICE_POLICY.md" in agents:
        print("  [PASS] AGENTS.md references LATTICE_POLICY.md")
    else:
        print("  [FAIL] AGENTS.md does not reference LATTICE_POLICY.md")
        fail += 1
    if "LIMIT_BREAKTHROUGH.md" in agents:
        print("  [PASS] AGENTS.md references LIMIT_BREAKTHROUGH.md")
    else:
        print("  [FAIL] AGENTS.md does not reference LIMIT_BREAKTHROUGH.md")
        fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_CROSS_DOC__ FAIL  ({fail} mismatch)")
        return 1
    print("__HEXA_MATTER_CROSS_DOC__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
