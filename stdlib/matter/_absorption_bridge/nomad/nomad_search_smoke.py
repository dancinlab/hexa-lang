#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
nomad_search_smoke.py — NOMAD (NOvel MAterials Discovery) adapter (smoke, offline replay).

Status: FUNCTIONAL (offline fixture replay PASS; live REST hits OUT-OF-SCOPE for --selftest).

NOMAD = NOvel MAterials Discovery (Draxl & Scheffler 2018 MRS Bull.;
Draxl & Scheffler 2019 J. Phys. Mater.). FAIR-data repository for
computational materials science hosted at nomad-lab.eu. Multi-code
DFT archive (VASP / Quantum ESPRESSO / FHI-aims / ABINIT / CP2K /
GPAW / many more), 19M+ DFT calculations as of 2024.

Two paths:
  1. Offline (`--selftest`): load `cache/sample_record.json`, validate schema
     (entry_id string, upload_id string, results.material present,
     results.method.simulation.program_name DFT code identifier,
     results.properties.energies.total numeric), emit sentinel. Always
     offline; deterministic.
  2. Live (`--entry-id <NOMAD-entry-id>`, optional): if stdlib
     `urllib.request` reachability is allowed, fetch
     `https://nomad-lab.eu/prod/v1/api/v1/entries/<entry_id>`. NOT exercised
     in --selftest. Identifies itself with a User-Agent.

The selftest never hits the network. The cache fixture is bundled.

It only validates schema + passes through. Records are multi-code DFT
PREDICTIONS, not measurements.

UNPROVEN preservation: NOMAD records preserve the originating DFT-code
identification (`program_name`) + functional + basis set so consumers can
trace methodological provenance. NOMAD does NOT curate synthesis status.

Optional dep: none (stdlib only — `urllib.request` for the live path).
            Optional `nomad-lab` PyPI client (`pip install nomad-lab`) may
            be used downstream; this adapter does NOT require it.
License: MIT (hexa-matter Phase G+2 adapter; NOMAD raw data is CC-BY 4.0
         per https://nomad-lab.eu/nomad-lab/services-uploads.html).
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

NOMAD_API_TEMPLATE = "https://nomad-lab.eu/prod/v1/api/v1/entries/{entry_id}"
USER_AGENT = "hexa-matter/0.1 (+https://github.com/dancinlab/hexa-matter) absorption_bridge/nomad"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_nomad_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate a NOMAD record (or fixture).

    Required fields (NOMAD V1 entry shape):
      entry_id (str), upload_id (str),
      results.material.chemical_formula_reduced (str),
      results.method.simulation.program_name (str — must indicate a DFT code),
      results.properties.energies.total (float),
      publication.

    Honest C3: verify the originating program is a DFT code — NOMAD aggregates
    multi-code DFT data, so the `program_name` identifies which DFT engine
    produced the record (VASP / QE / FHI-aims / ABINIT / CP2K / GPAW / …).
    """
    required_top = ["entry_id", "upload_id", "results", "publication"]
    for k in required_top:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["entry_id"], str) or not rec["entry_id"]:
        return False, f"entry_id not non-empty str: {rec.get('entry_id')!r}"
    if not isinstance(rec["upload_id"], str) or not rec["upload_id"]:
        return False, f"upload_id not non-empty str: {rec.get('upload_id')!r}"

    results = rec["results"]
    if not isinstance(results, dict):
        return False, f"results not dict"
    for path in ("material", "method", "properties"):
        if path not in results:
            return False, f"missing results.{path}"
    if "chemical_formula_reduced" not in results["material"]:
        return False, "missing results.material.chemical_formula_reduced"

    method = results["method"]
    if "simulation" not in method:
        return False, "missing results.method.simulation"
    sim = method["simulation"]
    if "program_name" not in sim:
        return False, "missing results.method.simulation.program_name"
    pn = str(sim["program_name"]).lower()
    # NOMAD aggregates multi-code DFT — accept the major codes plus generic markers.
    dft_codes = (
        "vasp", "quantum espresso", "qe", "fhi-aims", "abinit", "cp2k",
        "gpaw", "siesta", "exciting", "wien2k", "castep", "octopus",
        "elk", "fleur", "nwchem", "dft",
    )
    if not any(c in pn for c in dft_codes):
        return False, (
            f"program_name={pn!r} does not indicate a known DFT code; "
            "NOMAD records are multi-code DFT calculations"
        )

    properties = results["properties"]
    if "energies" not in properties:
        return False, "missing results.properties.energies"
    if "total" not in properties["energies"]:
        return False, "missing results.properties.energies.total"
    total = properties["energies"]["total"]
    if not isinstance(total, (int, float)):
        return False, f"results.properties.energies.total not numeric: {total!r}"

    # Honesty: synthesis status not curated by NOMAD; consumer must not assume measured.
    if "is_measurement" in rec and rec["is_measurement"] is True:
        return False, (
            "is_measurement=True for NOMAD record (NOMAD is computational; "
            "experimental data is a separate NOMAD-Oasis extension not aggregated here)"
        )

    return True, "ok"


def md5_stamp(payload: Any) -> str:
    """Deterministic md5 stamp for cache filename."""
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def fetch_entry_live(entry_id: str, timeout: float = 10.0) -> str:
    """Live REST entry fetch. NOT exercised in --selftest.

    Returns the JSON response text. Raises urllib.error.URLError on network failure.
    """
    url = NOMAD_API_TEMPLATE.format(entry_id=entry_id)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_NOMAD_SEARCH_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_NOMAD_SEARCH_SMOKE__ FAIL")
        return 1

    ok, reason = validate_nomad_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_NOMAD_SEARCH_SMOKE__ FAIL")
        return 1

    formula = rec["results"]["material"]["chemical_formula_reduced"]
    program = rec["results"]["method"]["simulation"]["program_name"]
    etotal = rec["results"]["properties"]["energies"]["total"]
    print(
        f"  PASS: fixture schema OK "
        f"(entry_id={rec['entry_id']}, formula={formula}, "
        f"program={program}, E_total={etotal} eV)"
    )

    # Honesty preservation — surface PREDICTION + multi-code provenance
    # per bridge rule #4 ("predictions ≠ measurements").
    print(
        f"  NOTE: program_name={program!r} — "
        "preserves originating-code provenance for downstream consumers)"
    )
    print(
        "  NOTE: live REST path https://nomad-lab.eu/prod/v1/api/v1/entries/ "
        "is OUT-OF-SCOPE for selftest (per NO LIVE API CALLS rule)"
    )

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_NOMAD_SEARCH_SMOKE__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument(
        "--entry-id",
        type=str,
        default=None,
        help="NOMAD entry ID (string). LIVE fetch; not used in --selftest.",
    )
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.entry_id:
        try:
            resp = fetch_entry_live(args.entry_id)
        except urllib.error.URLError as e:
            print(
                f"error: live NOMAD fetch failed for entry_id={args.entry_id}: {e}",
                file=sys.stderr,
            )
            return 2
        sys.stdout.write(resp)
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
