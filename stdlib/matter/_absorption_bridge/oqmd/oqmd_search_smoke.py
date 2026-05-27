#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
oqmd_search_smoke.py — Open Quantum Materials Database (OQMD) adapter (smoke, offline replay).

Status: FUNCTIONAL (offline fixture replay PASS; live REST hits OUT-OF-SCOPE for --selftest).

OQMD = Open Quantum Materials Database (Saal et al. 2013 JOM; Kirklin et al.
2015 npj Comput. Mater.). Wolverton group, Northwestern University. ~1M+ DFT
calculations of inorganic crystal structures (formation energies, stability,
phase diagrams). Updated rolling.

Two paths:
  1. Offline (`--selftest`): load `cache/sample_record.json`, validate schema
     (entry_id integer, formula, formation_energy_per_atom_eV float,
     stability_eV_per_atom float, prediction_method tag), emit sentinel.
     Always offline; deterministic.
  2. Live (`--entry-id NNNNNN`, optional): if stdlib `urllib.request`
     reachability is allowed, fetch `http://oqmd.org/oqmdapi/formationenergy?
     filter=entry_id=NNNNNN`. NOT exercised in --selftest. Polite cadence;
     identifies itself with a User-Agent.

The selftest never hits the network. The cache fixture is bundled.

It only validates schema + passes through. Records are DFT PREDICTIONS (PBE),
not measurements — clearly labelled in adapter output and SOURCES.md.

UNPROVEN preservation: OQMD records carry `prediction_method: DFT-PBE` and
`is_synthesized: unknown` markers (OQMD does not curate synthesis status;
many of the 1M entries are computational-only candidates).

Optional dep: none (stdlib only — `urllib.request` for the live path).
            Optional `qmpy_rester` Python client may be used downstream;
            this adapter does NOT require it.
License: MIT (hexa-matter Phase G+2 adapter; OQMD raw data is CC-BY 4.0 per
         http://oqmd.org/about — citation required to Saal 2013 + Kirklin 2015).
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

OQMD_API_TEMPLATE = "http://oqmd.org/oqmdapi/formationenergy?filter=entry_id={entry_id}"
USER_AGENT = "hexa-matter/0.1 (+https://github.com/dancinlab/hexa-matter) absorption_bridge/oqmd"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_oqmd_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate an OQMD record (or fixture).

    Required fields: entry_id (int), formula, composition, spacegroup,
    formation_energy_per_atom_eV (float), stability_eV_per_atom (float),
    prediction_method (str — must indicate DFT), publication.

    Honest C3: verify `prediction_method` actually indicates a DFT calculation
    (not measurement). OQMD records are PREDICTIONS; if a record claimed
    'experimental' it would be mis-labelled.
    """
    required = [
        "entry_id",
        "formula",
        "composition",
        "spacegroup",
        "formation_energy_per_atom_eV",
        "stability_eV_per_atom",
        "prediction_method",
        "publication",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["entry_id"], int) or rec["entry_id"] <= 0:
        return False, f"entry_id not positive int: {rec.get('entry_id')!r}"
    fe = rec["formation_energy_per_atom_eV"]
    if not isinstance(fe, (int, float)):
        return False, f"formation_energy_per_atom_eV not numeric: {fe!r}"
    stab = rec["stability_eV_per_atom"]
    if not isinstance(stab, (int, float)):
        return False, f"stability_eV_per_atom not numeric: {stab!r}"
    pm = str(rec.get("prediction_method", "")).lower()
    if "dft" not in pm and "predict" not in pm:
        return False, (
            f"prediction_method={pm!r} does not indicate DFT/prediction; "
            "OQMD records are DFT PREDICTIONS, not measurements"
        )
    if "experimental" in pm or "measured" in pm:
        return False, (
            f"prediction_method={pm!r} mis-labelled as experimental; "
            "OQMD records are DFT-PBE predictions"
        )
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    """Deterministic md5 stamp for cache filename."""
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def fetch_entry_live(entry_id: int, timeout: float = 10.0) -> str:
    """Live REST entry fetch. NOT exercised in --selftest.

    Returns the JSON response text. Raises urllib.error.URLError on network failure.
    """
    url = OQMD_API_TEMPLATE.format(entry_id=entry_id)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_OQMD_SEARCH_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_OQMD_SEARCH_SMOKE__ FAIL")
        return 1

    ok, reason = validate_oqmd_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_OQMD_SEARCH_SMOKE__ FAIL")
        return 1
    print(
        f"  PASS: fixture schema OK "
        f"(entry_id={rec['entry_id']}, formula={rec['formula']}, "
        f"ΔHf={rec['formation_energy_per_atom_eV']} eV/atom, "
        f"E_hull={rec['stability_eV_per_atom']} eV/atom)"
    )

    # Honesty preservation — surface PREDICTION distinction in adapter output
    # per bridge rule #4 ("predictions ≠ measurements").
    print(
        f"  NOTE: prediction_method={rec['prediction_method']!r} — "
        "DFT-PBE typical ΔHf MAE ~50-100 meV/atom)"
    )
    print(
        "  NOTE: live REST path http://oqmd.org/oqmdapi/ is "
        "OUT-OF-SCOPE for selftest (per NO LIVE API CALLS rule)"
    )

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_OQMD_SEARCH_SMOKE__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument(
        "--entry-id",
        type=int,
        default=None,
        help="OQMD numeric entry ID. LIVE fetch; not used in --selftest.",
    )
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.entry_id:
        try:
            resp = fetch_entry_live(args.entry_id)
        except urllib.error.URLError as e:
            print(
                f"error: live OQMD fetch failed for entry_id={args.entry_id}: {e}",
                file=sys.stderr,
            )
            return 2
        sys.stdout.write(resp)
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
