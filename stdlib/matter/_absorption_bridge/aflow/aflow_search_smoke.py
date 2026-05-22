#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
aflow_search_smoke.py — AFLOW (Automatic-FLOW for Materials Discovery) adapter (smoke, offline replay).

Status: FUNCTIONAL (offline fixture replay PASS; live REST hits OUT-OF-SCOPE for --selftest).

AFLOW = Automatic-FLOW for Materials Discovery (Curtarolo et al. 2012
Comput. Mater. Sci.; Toher et al. 2018 Mater. Today). Duke University
Curtarolo group. 3M+ DFT-computed compounds (the largest single computational
materials database as of 2024). Phase diagrams, thermal conductivity, elastic
properties, electronic structure.

Two paths:
  1. Offline (`--selftest`): load `cache/sample_record.json`, validate schema
     (auid string, compound, prototype_label, dft method tag, formation_enthalpy_atom_eV
     numeric), emit sentinel. Always offline; deterministic.
  2. Live (`--auid AFLOW-ID`, optional): if stdlib `urllib.request` reachability
     is allowed, fetch `http://aflow.org/API/aflux/?aurl=<auid>`. NOT
     exercised in --selftest. Identifies itself with a User-Agent.

The selftest never hits the network. The cache fixture is bundled.

It only validates schema + passes through. Records are DFT PREDICTIONS (mostly
PBE; some PBEsol / SCAN runs exist), not measurements.

UNPROVEN preservation: AFLOW records carry `dft_method` and `is_synthesized:
unknown` markers (AFLOW does not curate synthesis status; many entries are
prototype-substituted candidates).

Optional dep: none (stdlib only — `urllib.request` for the live path).
            Optional `aflow` PyPI client may be used downstream; this adapter
            does NOT require it.
License: MIT (hexa-matter Phase G+2 adapter; AFLOW raw data is CC-BY 4.0 per
         http://aflow.org/aflow-license.html — citation required to Curtarolo 2012).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_record.json"

AFLOW_API_TEMPLATE = "http://aflow.org/API/aflux/?aurl={auid}"
USER_AGENT = "hexa-matter/0.1 (+https://github.com/dancinlab/hexa-matter) absorption_bridge/aflow"

# AFLOW AUID format: aflow:<16-hex>. Used as a structural sanity-check on the fixture.
AUID_PATTERN = re.compile(r"^aflow:[0-9a-fA-F]{16}$")


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_aflow_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate an AFLOW record (or fixture).

    Required fields: auid (str matching aflow:HHHHHHHHHHHHHHHH),
    compound, prototype_label, spacegroup_relax, formation_enthalpy_atom_eV
    (float), enthalpy_atom_eV (float), dft_method (str — must indicate DFT),
    publication.

    Honest C3: verify `dft_method` indicates a DFT calculation. AFLOW records
    are PREDICTIONS; if a record claimed 'experimental' it would be mis-labelled.
    """
    required = [
        "auid",
        "compound",
        "prototype_label",
        "spacegroup_relax",
        "formation_enthalpy_atom_eV",
        "enthalpy_atom_eV",
        "dft_method",
        "publication",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    auid = rec["auid"]
    if not isinstance(auid, str) or not AUID_PATTERN.match(auid):
        return False, f"auid does not match aflow:<16-hex>: {auid!r}"
    fe = rec["formation_enthalpy_atom_eV"]
    if not isinstance(fe, (int, float)):
        return False, f"formation_enthalpy_atom_eV not numeric: {fe!r}"
    ea = rec["enthalpy_atom_eV"]
    if not isinstance(ea, (int, float)):
        return False, f"enthalpy_atom_eV not numeric: {ea!r}"
    dm = str(rec.get("dft_method", "")).lower()
    if "dft" not in dm and "pbe" not in dm and "scan" not in dm and "predict" not in dm:
        return False, (
            f"dft_method={dm!r} does not indicate DFT/PBE/SCAN/prediction; "
            "AFLOW records are DFT PREDICTIONS, not measurements"
        )
    if "experimental" in dm or "measured" in dm:
        return False, (
            f"dft_method={dm!r} mis-labelled as experimental; "
            "AFLOW records are DFT predictions"
        )
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    """Deterministic md5 stamp for cache filename."""
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def fetch_entry_live(auid: str, timeout: float = 10.0) -> str:
    """Live REST entry fetch. NOT exercised in --selftest.

    Returns the JSON response text. Raises urllib.error.URLError on network failure.
    """
    url = AFLOW_API_TEMPLATE.format(auid=auid)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_AFLOW_SEARCH_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_AFLOW_SEARCH_SMOKE__ FAIL")
        return 1

    ok, reason = validate_aflow_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_AFLOW_SEARCH_SMOKE__ FAIL")
        return 1
    print(
        f"  PASS: fixture schema OK "
        f"(auid={rec['auid']}, compound={rec['compound']}, "
        f"prototype={rec['prototype_label']}, "
        f"ΔHf={rec['formation_enthalpy_atom_eV']} eV/atom)"
    )

    # Honesty preservation — surface PREDICTION distinction in adapter output
    # per bridge rule #4 ("predictions ≠ measurements").
    print(
        f"  NOTE: dft_method={rec['dft_method']!r} — "
        "uses VASP PAW; per-record k-point + ENCUT documented in entry metadata)"
    )
    print(
        "  NOTE: live REST path http://aflow.org/API/aflux/ is "
        "OUT-OF-SCOPE for selftest (per NO LIVE API CALLS rule)"
    )

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_AFLOW_SEARCH_SMOKE__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument(
        "--auid",
        type=str,
        default=None,
        help="AFLOW unique ID (aflow:<16-hex>). LIVE fetch; not used in --selftest.",
    )
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.auid:
        if not AUID_PATTERN.match(args.auid):
            print(
                f"error: --auid must match aflow:<16-hex>, got {args.auid!r}",
                file=sys.stderr,
            )
            return 2
        try:
            resp = fetch_entry_live(args.auid)
        except urllib.error.URLError as e:
            print(
                f"error: live AFLOW fetch failed for auid={args.auid}: {e}",
                file=sys.stderr,
            )
            return 2
        sys.stdout.write(resp)
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
