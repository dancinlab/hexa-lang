#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
matlantis_call_smoke.py — Preferred Networks Matlantis adapter (offline replay).

Status: PARTIAL (offline fixture replay PASS; live SDK out-of-scope — COMMERCIAL).

Matlantis is a COMMERCIAL universal-NNP SaaS by Preferred Networks. The
underlying model is PFP (Preferred-network Foundation Potential — Takamoto et
al. 2022 Nat. Comm.). The SDK is proprietary and NOT installable in the
standard hexa-matter dev env; this adapter never tries to import it. We only
document the call shape and replay the bundled fixture for selftest.

Honest C3 (per INIT.md Phase G hard rule):
  - Matlantis is NOT free. Subscription pricing UNVERIFIED at hexa-matter
    scale economics.
  - The adapter SKIPs by default in any path other than --selftest.
  - For an open-source alternative at $0 license cost, see
    `_absorption_bridge/universal_ff/{mace_call,schnet_call,m3gnet_call,...}.py`.

published force MAE (~30 meV/Å on the benchmark suite).

License: MIT (hexa-matter Phase G adapter; the Matlantis SaaS itself is
commercial Preferred Networks).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_response.json"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_matlantis_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate a Matlantis PFP response (or fixture).

    Required: request_id, input_structure, predicted_total_energy_eV,
    predicted_energy_per_atom_eV, model, license.
    """
    required = [
        "request_id",
        "input_structure",
        "predicted_total_energy_eV",
        "predicted_energy_per_atom_eV",
        "model",
        "license",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    # Pricing-honesty marker: the fixture's license field must flag commercial.
    if "Commercial" not in rec["license"] and "commercial" not in rec["license"]:
        return False, f"license missing 'commercial' marker: {rec['license']!r}"

    if not isinstance(rec["predicted_total_energy_eV"], (int, float)):
        return False, "predicted_total_energy_eV not numeric"
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_MATLANTIS_CALL_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_MATLANTIS_CALL_SMOKE__ FAIL")
        return 1

    ok, reason = validate_matlantis_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_MATLANTIS_CALL_SMOKE__ FAIL")
        return 1
    print(f"  PASS: fixture schema OK (request_id={rec['request_id']}, model={rec['model']})")
    print(f"  PASS: license commercial-marker preserved")
    print(f"  NOTE: live Matlantis SDK is proprietary (Preferred Networks); selftest never imports it")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_MATLANTIS_CALL_SMOKE__ PASS")
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
