#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rosettafold_smoke.py — Baker Lab RoseTTAFold + RoseTTAFold All-Atom adapter.

Status: PARTIAL (offline fixture replay PASS; live RoseTTAFold path SKIPs).

Offline (`--selftest`): load `cache/sample_prediction.json`, validate
schema (chains, residue plddt, pae_mean, citation, license), emit sentinel.

Live: RoseTTAFold has no general-purpose PyPI distribution. Live use
requires the reference codebase from https://github.com/RosettaCommons/
RoseTTAFold (BSD-3) or https://github.com/baker-laboratory/RoseTTAFold-All-Atom
(Apache-2.0) + a CUDA-capable GPU. OUT-OF-SCOPE for the selftest.

C3: NO n=6 lattice-fit applied. RoseTTAFold carries its OWN
metrics — pLDDT, pAE, lDDT estimate.

UNPROVEN preservation: predictions are not measurements; novel folds
need experimental verification.

License: Apache-2.0 (hexa-bio cycle-30++++++++).
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
SAMPLE_FIXTURE = CACHE_DIR / "sample_prediction.json"
SENTINEL = "__HEXA_BIO_ROSETTAFOLD_SMOKE__"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_rosettafold_prediction(rec: dict) -> tuple[bool, str]:
    required = ["model_name", "target_id", "chains", "global_metrics", "license"]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if "RoseTTAFold" not in rec["model_name"] and "RFAA" not in rec["model_name"]:
        return False, f"model_name not RoseTTAFold-class: {rec['model_name']!r}"

    if not isinstance(rec["chains"], list) or len(rec["chains"]) == 0:
        return False, "chains must be a non-empty list"

    for i, ch in enumerate(rec["chains"]):
        for ck in ("chain_id", "n_residues", "residues"):
            if ck not in ch:
                return False, f"chain[{i}] missing field: {ck}"
        if not ch["residues"]:
            return False, f"chain[{i}].residues empty"
        first = ch["residues"][0]
        for rk in ("residue_idx", "plddt", "atom_xyz"):
            if rk not in first:
                return False, f"chain[{i}].residues[0] missing field: {rk}"
        if not (0.0 <= float(first["plddt"]) <= 100.0):
            return False, f"plddt out of [0, 100]: {first['plddt']!r}"

    gm = rec["global_metrics"]
    if "mean_plddt" not in gm:
        return False, "global_metrics missing mean_plddt"

    # Citation discipline: at least one of the two known RoseTTAFold papers.
    if "citation_original" not in rec and "citation_rfaa" not in rec:
        return False, "no Baker-Lab citation marker (Baek 2021 or Krishna 2024)"

    return True, "ok"


def md5_stamp(payload: Any) -> str:
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


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

    ok, reason = validate_rosettafold_prediction(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    print(f"  PASS: fixture schema OK (target_id={rec['target_id']}, "
          f"mean_plddt={rec['global_metrics']['mean_plddt']})")
    print(f"  PASS: Baker-Lab citation marker present")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("  NOTE: live RoseTTAFold inference requires reference codebase + CUDA — OUT-OF-SCOPE for selftest")
    print(f"{SENTINEL} PASS")
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
