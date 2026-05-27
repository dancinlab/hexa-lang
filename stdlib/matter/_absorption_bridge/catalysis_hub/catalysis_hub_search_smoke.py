#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
catalysis_hub_search_smoke.py — Catalysis-Hub (NTNU + Stanford SUNCAT) adapter
(smoke, offline replay).

Status: FUNCTIONAL (offline fixture replay PASS; live GraphQL hits OUT-OF-SCOPE for --selftest).

Catalysis-Hub = open electronic-structure database for surface reactions
(Winther et al. 2019 Sci. Data 6, 75; Schlexer Lamoureux et al. 2019
ChemCatChem 11, 3833). NTNU + Stanford SUNCAT. > 100,000 surface reactions /
adsorption energies; DFT-only — GPAW (default) + VASP, mostly BEEF-vdW.

Two paths:
  1. Offline (`--selftest`): load `cache/sample_record.json`, validate schema
     (reaction_id positive int, surface_facet non-empty, reaction_energy_eV
     numeric, prediction_method indicates DFT, xc_functional present),
     emit sentinel. Always offline; deterministic.
  2. Live (`--reaction-id NNNN`, optional): if stdlib `urllib.request`
     reachability is allowed, POST a small GraphQL query to
     `https://api.catalysis-hub.org/graphql`. NOT exercised in --selftest.
     Polite cadence ≥ 3 s observed; identifies itself with a User-Agent.

The selftest never hits the network. The cache fixture is bundled.

records. It only validates schema + passes through. Reaction-energy / E_a
values are DFT predictions with their OWN published error bars (BEEF-vdW
adsorption MAE ~0.1-0.2 eV; PBE looser). Clearly labelled as PREDICTION,
not MEASUREMENT, in adapter output and SOURCES.md.

UNPROVEN preservation: Catalysis-Hub records carry `is_synthesized: N/A`
(computational adsorption-energy DB; surface model only) and the validator
REJECTS any record mis-labelled as `experimental` / `measured`. This is the
inverse-discipline mirror of the COD adapter and the strict-prediction
sister of the NIMS MatNavi adapter's dual-mode tag.

Optional dep: none (stdlib only — `urllib.request` for the live path).
            Optional `catalysis-hub` PyPI wrapper may be used downstream;
            this adapter does NOT require it.
License: MIT (hexa-matter Phase J.3 adapter; Catalysis-Hub raw data is
         CC-BY 4.0, citation required to Winther 2019 + Schlexer Lamoureux 2019).
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

CATHUB_GRAPHQL_URL = "https://api.catalysis-hub.org/graphql"
USER_AGENT = "hexa-matter/0.1 (+https://github.com/dancinlab/hexa-matter) absorption_bridge/catalysis_hub"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_cathub_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate a Catalysis-Hub record (or fixture).

    Required fields: reaction_id (int), reaction_label, reactants, products,
    surface_facet, surface_composition, reaction_energy_eV (numeric),
    xc_functional, dft_code, prediction_method (must indicate DFT),
    publication.

    Honest C3: verify `prediction_method` actually indicates a DFT
    calculation (not measurement). Catalysis-Hub is DFT-only by construction
    (Winther 2019); if a record claimed `experimental`/`measured` it would
    be mis-labelled.
    """
    required = [
        "reaction_id",
        "reaction_label",
        "reactants",
        "products",
        "surface_facet",
        "surface_composition",
        "reaction_energy_eV",
        "xc_functional",
        "dft_code",
        "prediction_method",
        "publication",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["reaction_id"], int) or rec["reaction_id"] <= 0:
        return False, f"reaction_id not positive int: {rec.get('reaction_id')!r}"
    re_eV = rec["reaction_energy_eV"]
    if not isinstance(re_eV, (int, float)):
        return False, f"reaction_energy_eV not numeric: {re_eV!r}"
    if not isinstance(rec["surface_facet"], str) or not rec["surface_facet"].strip():
        return False, f"surface_facet not non-empty string: {rec.get('surface_facet')!r}"
    pm = str(rec.get("prediction_method", "")).lower()
    if "dft" not in pm and "predict" not in pm:
        return False, (
            f"prediction_method={pm!r} does not indicate DFT/prediction; "
            "Catalysis-Hub records are DFT predictions"
        )
    if "experimental" in pm or "measured" in pm:
        return False, (
            f"prediction_method={pm!r} mis-labelled as experimental; "
            "Catalysis-Hub records are DFT predictions (BEEF-vdW / GPAW + VASP)"
        )
    xc = str(rec.get("xc_functional", "")).strip()
    if not xc:
        return False, f"xc_functional missing/empty"
    code = str(rec.get("dft_code", "")).lower()
    # Catalysis-Hub default GPAW or VASP; allow other DFT codes too.
    if not any(c in code for c in ("gpaw", "vasp", "qe", "quantum espresso", "abinit", "fhi-aims", "dft")):
        return False, f"dft_code={code!r} not a recognised DFT engine"
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    """Deterministic md5 stamp for cache filename."""
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def fetch_reaction_live(reaction_id: int, timeout: float = 10.0) -> str:
    """Live GraphQL fetch by reaction_id. NOT exercised in --selftest.

    Returns the JSON response text. Raises urllib.error.URLError on network failure.
    """
    query = (
        '{ reactions(id: %d) { edges { node { id reactants products '
        'reactionEnergy activationEnergy chemicalComposition facet '
        'reactants products xcFunctional dftCode } } } }' % reaction_id
    )
    body = json.dumps({"query": query}).encode("utf-8")
    req = urllib.request.Request(
        CATHUB_GRAPHQL_URL,
        data=body,
        headers={
            "User-Agent": USER_AGENT,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_CATALYSIS_HUB_SEARCH_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_CATALYSIS_HUB_SEARCH_SMOKE__ FAIL")
        return 1

    ok, reason = validate_cathub_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_CATALYSIS_HUB_SEARCH_SMOKE__ FAIL")
        return 1
    print(
        f"  PASS: fixture schema OK "
        f"(reaction_id={rec['reaction_id']}, facet={rec['surface_facet']}, "
        f"ΔE_rxn={rec['reaction_energy_eV']} eV, xc={rec['xc_functional']}, "
        f"code={rec['dft_code']})"
    )

    # Honesty preservation — Catalysis-Hub is DFT-PREDICTION ONLY (rule #4).
    print(
        f"  NOTE: prediction_method={rec['prediction_method']!r} — "
        "adsorption-energy MAE ~0.1-0.2 eV vs experiment per Winther 2019)"
    )
    print(
        f"  NOTE: is_synthesized={rec.get('is_synthesized')!r} — surface model "
        "only; UNPROVEN at synthesis / process scale (computational adsorption-"
        "energy DB by construction)"
    )
    print(
        "  NOTE: live GraphQL path https://api.catalysis-hub.org/graphql is "
        "OUT-OF-SCOPE for selftest (per NO LIVE API CALLS rule)"
    )

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_CATALYSIS_HUB_SEARCH_SMOKE__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument(
        "--reaction-id",
        type=int,
        default=None,
        help="Catalysis-Hub numeric reaction ID. LIVE GraphQL fetch; not used in --selftest.",
    )
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.reaction_id:
        try:
            resp = fetch_reaction_live(args.reaction_id)
        except urllib.error.URLError as e:
            print(
                f"error: live Catalysis-Hub fetch failed for reaction_id={args.reaction_id}: {e}",
                file=sys.stderr,
            )
            return 2
        sys.stdout.write(resp)
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
