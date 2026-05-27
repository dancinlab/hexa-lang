#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mace_call.py — MACE (Batatia et al. 2022) universal-NNP adapter.

Status: PARTIAL (offline fixture-input schema PASS; live MACE forward
SKIPs without `mace-torch`).

MACE = Higher Order Equivariant Message Passing NN (NeurIPS 2022). Widely
used checkpoints include MACE-OMat (Meta, trained on OMat24) and the
mace-mp-0 small/medium/large family (trained on MPtrj).

The adapter:
  1. Loads bundled input structure fixture.
  2. Validates schema.
  3. If `mace-torch` is installed, would invoke MACE forward — but NOT in
     selftest (model checkpoint = ~hundreds of MB network fetch, breaks
     offline + determinism rules).

published force MAE (Batatia et al. 2022 NeurIPS).

Optional dep: mace-torch (`pip install mace-torch`)
License: MIT (hexa-matter Phase G adapter; MACE itself is MIT).
"""

from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_structure.json"

MODEL_NAME = "MACE"
SENTINEL = "__HEXA_MATTER_MACE_CALL__"
CITATION = "Batatia, I. et al. NeurIPS 2022 (arXiv:2206.07697)."


def _have_mace_torch() -> bool:
    try:
        import mace  # noqa: F401
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
    print(f"  NOTE: recommended checkpoint = mace-mp-0 (small/medium/large) or MACE-OMat-2024 (Meta)")

    if _have_mace_torch():
        print(f"  NOTE: mace-torch installed, but model load + forward is OUT-OF-SCOPE for selftest")
        print(f"{SENTINEL} PASS")
        return 0
    print(f"  SKIP: mace-torch not installed (install via `pip install mace-torch`)")
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
