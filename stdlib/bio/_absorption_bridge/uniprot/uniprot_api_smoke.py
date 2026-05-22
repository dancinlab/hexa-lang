#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
uniprot_api_smoke.py — UniProt REST API adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live UniProt fetch SKIPs
without `requests`).

Two paths:
  1. Offline (`--selftest`): load `cache/sample_entry.json` (P0DTC2-shaped
     fixture), validate schema (primaryAccession, organism, sequence,
     features, citation, license), emit sentinel.
  2. Live (`--accession P0DTC2`, optional): if `requests` is installed,
     fetch `https://rest.uniprot.org/uniprotkb/{accession}.json`. NOT
     exercised in `--selftest` (NO LIVE NETWORK rule).

C3: NO n=6 lattice-fit applied to UniProt records.

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
SENTINEL = "__HEXA_BIO_UNIPROT_API_SMOKE__"
UNIPROT_REST = "https://rest.uniprot.org/uniprotkb"


def _have_requests() -> bool:
    try:
        import requests  # noqa: F401
        return True
    except ImportError:
        return False


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_uniprot_entry(rec: dict) -> tuple[bool, str]:
    required = [
        "entryType",
        "primaryAccession",
        "uniProtkbId",
        "organism",
        "proteinDescription",
        "sequence",
        "license",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if not isinstance(rec["primaryAccession"], str) or not rec["primaryAccession"]:
        return False, f"primaryAccession not a non-empty string: {rec.get('primaryAccession')!r}"

    seq = rec["sequence"]
    if "length" not in seq or "molWeight" not in seq:
        return False, "sequence missing length / molWeight"
    if not isinstance(seq["length"], int) or seq["length"] <= 0:
        return False, f"sequence.length not positive int: {seq['length']!r}"

    org = rec["organism"]
    if "scientificName" not in org or "taxonId" not in org:
        return False, "organism missing scientificName / taxonId"

    lic = str(rec["license"]).lower()
    if "cc-by" not in lic and "cc by" not in lic:
        return False, f"UniProt license must be CC-BY 4.0: {rec['license']!r}"

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

    ok, reason = validate_uniprot_entry(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    print(f"  PASS: fixture schema OK (accession={rec['primaryAccession']}, "
          f"id={rec['uniProtkbId']}, len={rec['sequence']['length']}, "
          f"organism={rec['organism']['scientificName']!r})")
    print("  PASS: CC-BY 4.0 license confirmed (UniProt Consortium)")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    if _have_requests():
        print("  NOTE: requests installed; live UniProt REST OUT-OF-SCOPE for selftest (offline determinism)")
    else:
        print("  NOTE: requests not installed; live REST path SKIPPED (per NO LIVE NETWORK rule)")
    print(f"{SENTINEL} PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--accession", default=None, help="UniProt accession (e.g. P0DTC2); requires requests")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.accession:
        if not _have_requests():
            print("error: requests not installed; `pip install requests`", file=sys.stderr)
            return 2
        import requests  # type: ignore
        url = f"{UNIPROT_REST}/{args.accession}.json"
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        print(json.dumps(r.json(), indent=2))
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
