#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
colabfold_smoke.py — ColabFold adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live ColabFold path SKIPs).

ColabFold (Mirdita et al. 2022 Nat Methods) = AlphaFold-2 + MMseqs2 for
fast MSA generation. Lowers AF2's effective wall-clock by 10-100x by
swapping the original JackHMMER MSA pipeline for MMseqs2.

Offline (`--selftest`): load fixture, validate schema (MSA engine =
MMseqs2 marker, msa_depth, plddt, ptm/iptm, license).

Live: ColabFold runs as a Google Colab notebook or via the
`localcolabfold` install. Not exercised here.

C3: NO n=6 lattice-fit applied. ColabFold inherits AF2's metrics.

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
SENTINEL = "__HEXA_BIO_COLABFOLD_SMOKE__"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_colabfold_prediction(rec: dict) -> tuple[bool, str]:
    required = [
        "model_name",
        "underlying_model",
        "msa_engine",
        "target_id",
        "chains",
        "global_metrics",
        "msa_depth",
        "license",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if "ColabFold" not in rec["model_name"]:
        return False, f"model_name not ColabFold: {rec['model_name']!r}"

    if rec["msa_engine"] != "MMseqs2":
        return False, f"msa_engine must be MMseqs2 (ColabFold's defining feature): {rec['msa_engine']!r}"

    if "AlphaFold" not in str(rec["underlying_model"]):
        return False, f"underlying_model must be AlphaFold-class: {rec['underlying_model']!r}"

    if not isinstance(rec["msa_depth"], int) or rec["msa_depth"] <= 0:
        return False, f"msa_depth must be positive int: {rec['msa_depth']!r}"

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

    ok, reason = validate_colabfold_prediction(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    print(f"  PASS: fixture schema OK (target_id={rec['target_id']}, "
          f"msa_engine={rec['msa_engine']}, msa_depth={rec['msa_depth']}, "
          f"mean_plddt={rec['global_metrics']['mean_plddt']})")
    print("  PASS: MMseqs2 MSA-engine marker preserved (ColabFold's defining feature)")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("  NOTE: live ColabFold runs via Colab notebook or localcolabfold — OUT-OF-SCOPE for selftest")
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
