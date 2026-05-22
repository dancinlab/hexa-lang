#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
omat24_dataset_smoke.py — Meta AI OMat24 dataset adapter (offline schema replay).

Status: PARTIAL (offline fixture replay PASS; live HF datasets fetch OUT-OF-SCOPE).

OMat24 = Open Materials 2024 (Barroso-Luque et al. 2024, arXiv:2410.12771).
~110M DFT-computed structures + the MACE-OMat NNP checkpoint.

Hosted at HuggingFace:
  - dataset:   fairchem/OMAT24
  - checkpoint: fairchem/MACE-OMat-2024

records. They carry their OWN DFT error bars (same caveats as MP/PBE).

Optional dep (live fetch): `huggingface_hub` (`pip install huggingface_hub`).
Not exercised in --selftest.

License: MIT (hexa-matter Phase G adapter; OMat24 itself is CC-BY 4.0).
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
SAMPLE_FIXTURE = CACHE_DIR / "sample_record.json"


def _have_huggingface_hub() -> bool:
    try:
        import huggingface_hub  # noqa: F401
        return True
    except ImportError:
        return False


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_omat24_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate an OMat24 record (or fixture).

    Required: omat24_id, formula, elements, nsites, dft_total_energy_eV,
    dft_energy_per_atom_eV, structure.
    """
    required = [
        "omat24_id",
        "formula",
        "elements",
        "nsites",
        "dft_total_energy_eV",
        "dft_energy_per_atom_eV",
        "structure",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["nsites"], int) or rec["nsites"] <= 0:
        return False, f"nsites not positive int: {rec.get('nsites')!r}"
    if "lattice" not in rec["structure"]:
        return False, "structure.lattice missing"
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_OMAT24_DATASET_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_OMAT24_DATASET_SMOKE__ FAIL")
        return 1

    ok, reason = validate_omat24_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_OMAT24_DATASET_SMOKE__ FAIL")
        return 1
    print(f"  PASS: fixture schema OK (omat24_id={rec['omat24_id']}, formula={rec['formula']})")

    if _have_huggingface_hub():
        print("  NOTE: huggingface_hub installed, but live HF fetch OUT-OF-SCOPE for selftest")
    else:
        print("  NOTE: huggingface_hub not installed; live HF fetch SKIPPED in selftest")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_OMAT24_DATASET_SMOKE__ PASS")
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
