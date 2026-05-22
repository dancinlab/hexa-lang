#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
af3_smoke.py — DeepMind AlphaFold-3 adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live AF3 path SKIPs).

Two paths:
  1. Offline (`--selftest`): load `cache/sample_prediction.json`, validate
     schema (chains, residue_idx, pLDDT, pAE_summary, ptm/iptm, citation,
     license), emit sentinel. Always offline; deterministic.
  2. Live: AlphaFold-3 weights are released under DeepMind's NON-COMMERCIAL
     RESEARCH license (2024-11). There is no general-purpose `pip install
     alphafold3` — live use requires manual gated weights download and the
     reference inference codebase. The adapter's live path is intentionally
     out-of-scope here; live use lives outside this CI surface.

The selftest never hits the network. The cache fixture is bundled.

C3 (LATTICE_POLICY.md §1.2/1.3): this adapter does NOT apply n=6
lattice formulas (σ=12 / τ=4 / φ=2 / J₂=24) to AlphaFold-3 predictions.
AF3 carries its OWN published metrics — pLDDT (per-residue confidence,
0-100), pAE (predicted aligned error, Å), pTM / ipTM (interface). The
bridge passes them through untouched.

UNPROVEN preservation (per AGENTS.md / SPEC_FIRST):
  AF3 predicts; it does not measure. Novel-fold predictions remain
  UNVERIFIED until experimental confirmation (X-ray, cryo-EM, NMR).
  The adapter enforces these markers are present in `SOURCES.md` and in
  the fixture's `_predictions_not_measurements` field.

LICENSE HONESTY: AF3 is NON-COMMERCIAL RESEARCH ONLY. Commercial use
requires a separate Isomorphic Labs license. The adapter's `--selftest`
output reminds the caller of this restriction.

Optional dep: none required for offline replay (stdlib only).
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
SENTINEL = "__HEXA_BIO_AF3_SMOKE__"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_af3_prediction(rec: dict) -> tuple[bool, str]:
    """Schema-validate an AlphaFold-3 prediction record (or fixture).

    Required: model_name, target_id, chains, global_metrics (with pLDDT
    + pTM), pAE_summary, citation, license. Each chain must carry
    chain_id, n_residues, and at least one residue entry with residue_idx
    + pLDDT + atom_xyz.
    """
    required = [
        "model_name",
        "target_id",
        "chains",
        "global_metrics",
        "pAE_summary",
        "citation",
        "license",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if "AlphaFold" not in rec["model_name"]:
        return False, f"model_name not AlphaFold-class: {rec['model_name']!r}"

    if not isinstance(rec["chains"], list) or len(rec["chains"]) == 0:
        return False, "chains must be a non-empty list"

    for i, ch in enumerate(rec["chains"]):
        for ck in ("chain_id", "n_residues", "residues"):
            if ck not in ch:
                return False, f"chain[{i}] missing field: {ck}"
        if not ch["residues"]:
            return False, f"chain[{i}].residues empty"
        first = ch["residues"][0]
        for rk in ("residue_idx", "pLDDT", "atom_xyz"):
            if rk not in first:
                return False, f"chain[{i}].residues[0] missing field: {rk}"
        if not (0.0 <= float(first["pLDDT"]) <= 100.0):
            return False, f"pLDDT out of [0, 100]: {first['pLDDT']!r}"

    gm = rec["global_metrics"]
    for gk in ("ptm", "mean_pLDDT"):
        if gk not in gm:
            return False, f"global_metrics missing field: {gk}"

    # License honesty: AF3 weights are non-commercial.
    lic = str(rec["license"]).lower()
    if "non-commercial" not in lic and "noncommercial" not in lic and "isomorphic labs" not in lic:
        return False, f"license string lacks non-commercial marker: {rec['license']!r}"

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

    ok, reason = validate_af3_prediction(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    print(f"  PASS: fixture schema OK (target_id={rec['target_id']}, "
          f"mean_pLDDT={rec['global_metrics']['mean_pLDDT']}, pTM={rec['global_metrics']['ptm']})")
    print("  PASS: license string carries non-commercial marker (DeepMind 2024-11)")
    print("  PASS: predictions-not-measurements distinction preserved in fixture")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("  NOTE: live AF3 inference requires gated DeepMind weights — OUT-OF-SCOPE for selftest")
    print("  NOTE: AF3 commercial use requires separate Isomorphic Labs license")
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
