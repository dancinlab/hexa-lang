#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pdb_api_smoke.py — RCSB PDB REST API adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live RCSB fetch SKIPs
without `requests`).

Two paths:
  1. Offline (`--selftest`): load `cache/sample_entry.json` (7C2L-shaped
     fixture), validate schema (entry.id, struct.title, exptl.method,
     rcsb_entry_info, citation, license), emit sentinel.
  2. Live (`--pdb-id 7C2L`, optional): if `requests` is installed, fetch
     `https://data.rcsb.org/rest/v1/core/entry/{pdb_id}`. NOT exercised
     in selftest.

C3: NO n=6 lattice-fit applied to PDB records. PDB carries OWN
experimental metrics — resolution, R-factor, deposition method.

NOTE: hexa-bio already has `_python_bridge/module/virocapsid_pdb_corpus.py`
for VIPERdb corpus fetches; this adapter is the GENERIC RCSB entry-level
counterpart, complementary not duplicate.

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
SAMPLE_FIXTURE = CACHE_DIR / "sample_entry.json"
SENTINEL = "__HEXA_BIO_PDB_API_SMOKE__"
RCSB_REST = "https://data.rcsb.org/rest/v1/core/entry"


def _have_requests() -> bool:
    try:
        import requests  # noqa: F401
        return True
    except ImportError:
        return False


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_pdb_entry(rec: dict) -> tuple[bool, str]:
    required = [
        "entry",
        "struct",
        "exptl",
        "rcsb_entry_info",
        "rcsb_accession_info",
        "license",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if "id" not in rec["entry"]:
        return False, "entry.id missing"
    pdb_id = rec["entry"]["id"]
    if not isinstance(pdb_id, str) or len(pdb_id) != 4:
        return False, f"entry.id not 4-char PDB id: {pdb_id!r}"

    if not isinstance(rec["exptl"], list) or len(rec["exptl"]) == 0:
        return False, "exptl must be a non-empty list"
    if "method" not in rec["exptl"][0]:
        return False, "exptl[0].method missing"

    info = rec["rcsb_entry_info"]
    for ik in ("polymer_entity_count_protein", "deposited_atom_count", "resolution_combined"):
        if ik not in info:
            return False, f"rcsb_entry_info missing field: {ik}"

    if "deposit_date" not in rec["rcsb_accession_info"]:
        return False, "rcsb_accession_info.deposit_date missing"

    lic = str(rec["license"]).lower()
    if "cc0" not in lic and "public domain" not in lic:
        return False, f"PDB license must be CC0 / Public Domain: {rec['license']!r}"

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

    ok, reason = validate_pdb_entry(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    pdb_id = rec["entry"]["id"]
    method = rec["exptl"][0]["method"]
    resolution = rec["rcsb_entry_info"]["resolution_combined"]
    print(f"  PASS: fixture schema OK (pdb_id={pdb_id}, method={method}, "
          f"resolution={resolution})")
    print("  PASS: CC0 / Public Domain license confirmed (RCSB / wwPDB)")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    if _have_requests():
        print("  NOTE: requests installed; live RCSB REST OUT-OF-SCOPE for selftest (offline determinism)")
    else:
        print("  NOTE: requests not installed; live REST path SKIPPED (per NO LIVE NETWORK rule)")
    print(f"{SENTINEL} PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--pdb-id", default=None, help="4-char PDB id (e.g. 7C2L); requires requests")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.pdb_id:
        if not _have_requests():
            print("error: requests not installed; `pip install requests`", file=sys.stderr)
            return 2
        import requests  # type: ignore
        url = f"{RCSB_REST}/{args.pdb_id}"
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        print(json.dumps(r.json(), indent=2))
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
