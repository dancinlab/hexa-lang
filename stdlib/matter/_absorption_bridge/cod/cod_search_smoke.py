#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cod_search_smoke.py — Crystallography Open Database (COD) adapter (smoke, offline replay).

Status: FUNCTIONAL (offline fixture replay PASS; live REST hits OUT-OF-SCOPE for --selftest).

COD = Crystallography Open Database (Gražulis et al. 2009 J. Appl. Crystallogr. + 2012
Nucleic Acids Res.). Open-access collection of EXPERIMENTAL crystal structures
deposited by authors. ≥ 500,000 records (as of 2024).

Two paths:
  1. Offline (`--selftest`): load `cache/sample_record.json`, validate schema
     (cod_id integer, cell.a > 0, spacegroup_it int, measurement_type tag),
     emit sentinel. Always offline; deterministic.
  2. Live (`--cod-id NNNNNNN`, optional): if stdlib `urllib.request` reachability
     is allowed, fetch `http://www.crystallography.net/cod/<id>.cif`. NOT
     exercised in --selftest. Polite cadence ≤ 1 req / 3 s observed; identifies
     itself with a User-Agent.

The selftest never hits the network. The cache fixture is bundled.

It only validates schema + passes through the record. Records are EXPERIMENTAL
MEASUREMENTS, not predictions — clearly labelled in adapter output and SOURCES.md.

Optional dep: none (stdlib only — `urllib.request` for the live path).
            Optional `pymatgen` may parse the resulting CIF downstream
            (handled by `_python_bridge/module/pymatgen_structure_io.py`,
            not by this adapter).
License: MIT (hexa-matter Phase G+1 adapter; COD raw data is CC0 / public domain).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_record.json"

COD_CIF_TEMPLATE = "http://www.crystallography.net/cod/{cod_id}.cif"
USER_AGENT = "hexa-matter/0.1 (+https://github.com/dancinlab/hexa-matter) absorption_bridge/cod"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_cod_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate a COD record (or fixture).

    Required fields: cod_id (int), formula, elements, nsites,
    spacegroup_hm, spacegroup_it, cell.{a,b,c,alpha,beta,gamma},
    measurement_type, publication.

    Honest C3: also verify `measurement_type` actually indicates measurement
    (not prediction). COD records are EXPERIMENTAL; if a record claimed
    'predicted' we should reject it as not-COD-shaped.
    """
    required = [
        "cod_id",
        "formula",
        "elements",
        "nsites",
        "spacegroup_hm",
        "spacegroup_it",
        "cell",
        "measurement_type",
        "publication",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["cod_id"], int) or rec["cod_id"] <= 0:
        return False, f"cod_id not positive int: {rec.get('cod_id')!r}"
    if not isinstance(rec["spacegroup_it"], int) or not (1 <= rec["spacegroup_it"] <= 230):
        return False, f"spacegroup_it out of [1,230]: {rec.get('spacegroup_it')!r}"
    cell = rec["cell"]
    for k in ("a", "b", "c", "alpha", "beta", "gamma"):
        if k not in cell:
            return False, f"cell.{k} missing"
        v = cell[k]
        if not isinstance(v, (int, float)) or v <= 0:
            return False, f"cell.{k} not positive: {v!r}"
    mtype = str(rec.get("measurement_type", "")).lower()
    if "experimental" not in mtype and "measured" not in mtype:
        return False, (
            f"measurement_type={mtype!r} does not indicate experiment; "
            "COD records are MEASUREMENTS, not predictions"
        )
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    """Deterministic md5 stamp for cache filename."""
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def fetch_cif_live(cod_id: int, timeout: float = 10.0) -> str:
    """Live REST CIF fetch. NOT exercised in --selftest.

    Polite cadence is the caller's responsibility (≤ 1 req / 3 s).
    Returns the CIF text. Raises urllib.error.URLError on network failure.
    """
    url = COD_CIF_TEMPLATE.format(cod_id=cod_id)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_COD_SEARCH_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_COD_SEARCH_SMOKE__ FAIL")
        return 1

    ok, reason = validate_cod_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_COD_SEARCH_SMOKE__ FAIL")
        return 1
    print(
        f"  PASS: fixture schema OK "
        f"(cod_id={rec['cod_id']}, formula={rec['formula']}, "
        f"a={rec['cell']['a']} Å, sg#{rec['spacegroup_it']})"
    )

    # Honesty preservation — surface MEASUREMENT vs PREDICTION distinction
    # in adapter output, per bridge rule #4 ("predictions ≠ measurements").
    print(
        f"  NOTE: measurement_type={rec['measurement_type']!r} — "
    )
    print(
        "  NOTE: live REST path http://www.crystallography.net/cod/<id>.cif is "
        "OUT-OF-SCOPE for selftest (per NO LIVE API CALLS rule)"
    )

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_COD_SEARCH_SMOKE__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument(
        "--cod-id",
        type=int,
        default=None,
        help="COD numeric ID (e.g. 9008565 = Si). LIVE fetch; not used in --selftest.",
    )
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.cod_id:
        try:
            cif = fetch_cif_live(args.cod_id)
        except urllib.error.URLError as e:
            print(
                f"error: live COD fetch failed for cod_id={args.cod_id}: {e}",
                file=sys.stderr,
            )
            return 2
        sys.stdout.write(cif)
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
