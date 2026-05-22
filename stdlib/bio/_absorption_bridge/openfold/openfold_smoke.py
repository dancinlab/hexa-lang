#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
openfold_smoke.py — OpenFold adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live OpenFold path SKIPs).

OpenFold (Ahdritz et al. 2024 Nat Methods) is the open-source,
trainable PyTorch reimplementation of AlphaFold-2 maintained by the
AlQuraishi lab (Columbia) + the OpenFold consortium. Apache-2.0 — useful
when AF3's non-commercial restriction matters AND a trainable backbone
is needed.

Offline (`--selftest`): load fixture, validate schema.

Live: OpenFold (GitHub: `aqlaboratory/openfold`) needs PyTorch + DeepMind
parameter ports + a CUDA GPU. OUT-OF-SCOPE for selftest.

C3: NO n=6 lattice-fit applied.

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
SENTINEL = "__HEXA_BIO_OPENFOLD_SMOKE__"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_openfold_prediction(rec: dict) -> tuple[bool, str]:
    required = ["model_name", "target_id", "trainable", "chains", "global_metrics", "license"]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if "OpenFold" not in rec["model_name"]:
        return False, f"model_name not OpenFold: {rec['model_name']!r}"

    # OpenFold's defining feature: trainability.
    if rec["trainable"] is not True:
        return False, "trainable must be True — OpenFold is the trainable AF2 reimpl"

    if "apache" not in str(rec["license"]).lower() and "Apache" not in str(rec["license"]):
        return False, f"OpenFold license must be Apache-2.0: {rec['license']!r}"

    if not isinstance(rec["chains"], list) or not rec["chains"]:
        return False, "chains must be non-empty list"

    first_res = rec["chains"][0]["residues"][0]
    for rk in ("residue_idx", "plddt", "atom_xyz"):
        if rk not in first_res:
            return False, f"residues[0] missing field: {rk}"

    if "mean_plddt" not in rec["global_metrics"]:
        return False, "global_metrics missing mean_plddt"

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

    ok, reason = validate_openfold_prediction(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    print(f"  PASS: fixture schema OK (target_id={rec['target_id']}, "
          f"trainable={rec['trainable']}, mean_plddt={rec['global_metrics']['mean_plddt']})")
    print(f"  PASS: Apache-2.0 license confirmed (commercial-OK alternative to AF3)")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("  NOTE: live OpenFold inference requires aqlaboratory/openfold + CUDA — OUT-OF-SCOPE for selftest")
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
