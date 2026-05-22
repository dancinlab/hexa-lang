#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
m3gnet_call.py — M3GNet (Chen & Ong 2022) universal-NNP adapter (via MatGL).

Status: PARTIAL (offline fixture-input schema PASS; live M3GNet forward
SKIPs without `matgl`).

M3GNet = Materials 3-body Graph Network. Trained on MPF.2021.2.8. Successor
library `matgl` (Materials Graph Library) now hosts both M3GNet and a newer
TensorNet model under one roof.

The adapter validates input-structure schema offline and SKIPs live forward
when `matgl` is missing.

published force MAE (Chen & Ong 2022 Nat. Comput. Sci.).

Optional dep: matgl (`pip install matgl`)
License: MIT (hexa-matter Phase G adapter; M3GNet itself is BSD-3-Clause via matgl).
"""

from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_structure.json"

MODEL_NAME = "M3GNet"
SENTINEL = "__HEXA_MATTER_M3GNET_CALL__"
CITATION = "Chen, C. & Ong, S. P. Nat. Comput. Sci. 2, 718 (2022)."


def _have_matgl() -> bool:
    try:
        import matgl  # noqa: F401
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
    print(f"  NOTE: trained on MPF.2021.2.8; consumed via `matgl` library (M3GNet successor home)")

    if _have_matgl():
        print(f"  NOTE: matgl installed, but model load + forward is OUT-OF-SCOPE for selftest")
        print(f"{SENTINEL} PASS")
        return 0
    print(f"  SKIP: matgl not installed (install via `pip install matgl`)")
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
