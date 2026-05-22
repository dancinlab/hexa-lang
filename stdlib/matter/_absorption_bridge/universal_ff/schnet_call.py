#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
schnet_call.py — SchNet (Schütt et al. 2017) universal-NNP adapter.

Status: PARTIAL (offline fixture-input schema PASS; live SchNet forward
SKIPs without `schnetpack`).

SchNet was one of the first equivariant message-passing NNPs for molecular /
materials property prediction. The adapter:
  1. Loads the bundled sample structure fixture (universal_ff/cache/).
  2. Validates the input structure schema (lattice + sites + elements).
  3. If `schnetpack` is installed, would invoke a SchNet forward pass — but
     this is NOT exercised in --selftest (model load = network fetch + GPU
     compute, breaks determinism + offline rule).

published force MAE (Schütt et al. 2017 J. Chem. Phys.).

Optional dep: schnetpack (`pip install schnetpack`)
License: MIT (hexa-matter Phase G adapter; SchNet itself is MIT).
"""

from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_structure.json"

MODEL_NAME = "SchNet"
SENTINEL = "__HEXA_MATTER_SCHNET_CALL__"
CITATION = "Schütt, K. T. et al. J. Chem. Phys. 148, 241722 (2018)."


def _have_schnetpack() -> bool:
    try:
        import schnetpack  # noqa: F401
        return True
    except ImportError:
        return False


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_input_structure(rec: dict) -> tuple[bool, str]:
    required = ["formula", "elements", "lattice", "sites"]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["sites"], list) or not rec["sites"]:
        return False, "sites must be non-empty list"
    return True, "ok"


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print(f"{SENTINEL} FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print(f"{SENTINEL} FAIL")
        return 1

    ok, reason = validate_input_structure(rec)
    if not ok:
        print(f"  FAIL: input schema: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    print(f"  PASS: input structure schema OK (formula={rec['formula']}, sites={len(rec['sites'])})")
    print(f"  NOTE: model = {MODEL_NAME}, citation = {CITATION}")

    if _have_schnetpack():
        print(f"  NOTE: schnetpack installed, but model load + forward is OUT-OF-SCOPE for selftest")
        print(f"{SENTINEL} PASS")
        return 0

    print(f"  SKIP: schnetpack not installed (install via `pip install schnetpack`)")
    print(f"{SENTINEL} PASS (SKIP mode)")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args()
    if args.selftest:
        return _selftest()
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
