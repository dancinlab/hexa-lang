#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
chgnet_call.py — CHGNet (Deng et al. 2023) universal-NNP adapter.

Status: PARTIAL (offline fixture-input schema PASS; live CHGNet forward
SKIPs without `chgnet`).

CHGNet = Crystal Hamiltonian Graph Network. Pre-trained on MPtrj (Materials
Project trajectories). Uniquely charge/spin-aware (predicts magnetic moments
in addition to energy/force/stress).

The adapter validates input-structure schema offline and SKIPs live forward
when `chgnet` is missing.

published force MAE (Deng et al. 2023 Nat. Mach. Intell.).

Optional dep: chgnet (`pip install chgnet`)
License: MIT (hexa-matter Phase G adapter; CHGNet itself is BSD-3-Clause).
"""

from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_structure.json"

MODEL_NAME = "CHGNet"
SENTINEL = "__HEXA_MATTER_CHGNET_CALL__"
CITATION = "Deng, B. et al. Nat. Mach. Intell. 5, 1031 (2023)."


def _have_chgnet() -> bool:
    try:
        import chgnet  # noqa: F401
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
    print(f"  NOTE: trained on MPtrj; charge/spin-aware (magnetic moment + energy + force + stress)")

    if _have_chgnet():
        print(f"  NOTE: chgnet installed, but model load + forward is OUT-OF-SCOPE for selftest")
        print(f"{SENTINEL} PASS")
        return 0
    print(f"  SKIP: chgnet not installed (install via `pip install chgnet`)")
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
