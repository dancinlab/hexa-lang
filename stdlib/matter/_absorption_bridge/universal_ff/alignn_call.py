#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
alignn_call.py — ALIGNN (Choudhary & DeCost 2021) universal-NNP adapter.

Status: PARTIAL (offline fixture-input schema PASS; live ALIGNN forward
SKIPs without `alignn`).

ALIGNN = Atomistic Line Graph Neural Network (NIST). Strong at materials
property regression (band gap, formation energy, elastic moduli). Trained on
JARVIS-DFT.

The adapter validates input-structure schema offline and SKIPs live forward
when `alignn` is missing.

published MAE per property (Choudhary & DeCost 2021).

Optional dep: alignn (`pip install alignn`)
License: MIT (hexa-matter Phase G adapter; ALIGNN itself NIST open-source).
"""

from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_structure.json"

MODEL_NAME = "ALIGNN"
SENTINEL = "__HEXA_MATTER_ALIGNN_CALL__"
CITATION = "Choudhary, K. & DeCost, B. npj Comput. Mater. 7, 185 (2021)."


def _have_alignn() -> bool:
    try:
        import alignn  # noqa: F401
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
    print(f"  NOTE: trained on JARVIS-DFT; strong at property regression (band gap, formation energy)")

    if _have_alignn():
        print(f"  NOTE: alignn installed, but model load + forward is OUT-OF-SCOPE for selftest")
        print(f"{SENTINEL} PASS")
        return 0
    print(f"  SKIP: alignn not installed (install via `pip install alignn`)")
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
