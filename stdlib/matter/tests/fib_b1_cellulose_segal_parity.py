#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/fib_b1_cellulose_segal_parity.py — Phase I.1 gate B-FIB-1.

Anchor: TAPPI T 271 + Segal et al. 1959 (Textile Res. J. 29, 786-794) —
kraft cellulose crystallinity index (Segal CrI by XRD) 60-80 % (wood pulp
60-70 %, native cotton ~ 80 %).

Parity: wood-cellulose/wood-cellulose.md WC-L12 row ↔
tests/snapshots/fib_b1_cellulose_segal.json. Tolerance: ± 10 % on each
endpoint of the 60-80 % band.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __FIB_B1_CELLULOSE_SEGAL__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "fib_b1_cellulose_segal.json")
SPEC_DOC = os.path.join(ROOT, "wood-cellulose", "wood-cellulose.md")
SENTINEL = "__FIB_B1_CELLULOSE_SEGAL__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_lo = float(snap["claim"]["CrI_pct_min"])
    src_hi = float(snap["claim"]["CrI_pct_max"])
    tol = float(snap["tolerance"]["CrI_band_abs_pct"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"WC-L12.*?cotton\s*~\s*([0-9]+)\s*%.*?wood pulp\s*([0-9]+)\s*[-–]\s*([0-9]+)\s*%",
        text,
    )
    if not m:
        print("FAIL: could not locate WC-L12 CrI claim in wood-cellulose/wood-cellulose.md")
        return 1
    spec_cotton = float(m.group(1))
    spec_wp_lo = float(m.group(2))
    spec_wp_hi = float(m.group(3))
    # Spec spans wood-pulp (60-70) → cotton (80) → range 60-80.
    spec_lo = spec_wp_lo
    spec_hi = spec_cotton
    lo_delta = abs(spec_lo - src_lo)
    hi_delta = abs(spec_hi - src_hi)
    print(f"  spec   WC-L12 CrI band wood-pulp..cotton = {spec_lo}-{spec_hi} %")
    print(f"  source TAPPI T 271 + Segal 1959           = {src_lo}-{src_hi} %")
    print(f"  delta  lo={lo_delta} hi={hi_delta} (tolerance abs {tol})")
    if lo_delta > tol or hi_delta > tol:
        print(f"FAIL: CrI range delta > tolerance {tol} %")
        return 1
    print(f"PASS: spec kraft-cellulose CrI within TAPPI/Segal tolerance ± {tol} %")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: fib_b1_cellulose_segal_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
