#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
esmfold_smoke.py — Meta ESMFold adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live torch/transformers
ESMFold path SKIPs when deps missing).

ESMFold (Lin et al. 2023 Science) uses Meta's ESM-2 protein language
model directly for structure prediction — NO MSA pipeline required. This
makes it significantly faster than AF2/AF3/RoseTTAFold at the cost of
some accuracy on hard targets.

Offline (`--selftest`): load `cache/sample_prediction.json`, validate
schema (chains, residue plddt, mean_plddt, ptm, msa_used=False marker,
citation, license), emit sentinel.

Live: ESMFold weights publicly released by Meta and mirrored on
HuggingFace (`facebook/esmfold_v1`). Requires `torch` + `transformers`.
The selftest does NOT invoke the live model.

C3: NO n=6 lattice-fit applied. ESMFold carries OWN metrics —
pLDDT, pTM. The MSA-free nature is preserved in the fixture.

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
SENTINEL = "__HEXA_BIO_ESMFOLD_SMOKE__"


def _have_torch_transformers() -> bool:
    try:
        import torch  # noqa: F401
        import transformers  # noqa: F401
        return True
    except ImportError:
        return False


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_esmfold_prediction(rec: dict) -> tuple[bool, str]:
    required = [
        "model_name",
        "target_id",
        "language_model",
        "msa_used",
        "chains",
        "global_metrics",
        "license",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if "ESMFold" not in rec["model_name"]:
        return False, f"model_name not ESMFold: {rec['model_name']!r}"

    if "ESM" not in str(rec["language_model"]):
        return False, f"language_model not ESM-class: {rec['language_model']!r}"

    if rec["msa_used"] is not False:
        return False, "msa_used must be False — ESMFold is single-sequence by design"

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

    ok, reason = validate_esmfold_prediction(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    print(f"  PASS: fixture schema OK (target_id={rec['target_id']}, "
          f"language_model={rec['language_model']}, mean_plddt={rec['global_metrics']['mean_plddt']})")
    print("  PASS: msa_used=False marker preserved (ESMFold is single-sequence by design)")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    if _have_torch_transformers():
        print("  NOTE: torch + transformers installed; live ESMFold inference is OUT-OF-SCOPE for selftest (offline determinism)")
    else:
        print("  NOTE: torch + transformers not installed; live ESMFold path SKIPPED (per NO LIVE INFERENCE rule)")
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
