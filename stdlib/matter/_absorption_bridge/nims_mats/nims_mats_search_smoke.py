#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
nims_mats_search_smoke.py — NIMS Materials Database (MatNavi / MITS) adapter
(smoke, offline replay).

Status: FUNCTIONAL (offline fixture replay PASS; live web search OUT-OF-SCOPE for --selftest).

NIMS Materials Database = National Institute for Materials Science (Tsukuba,
Japan) materials data hub. MatNavi web portal aggregates ~50,000 records
across metals · alloys · ceramics · polymers · composites · creep · fatigue
· thermal · corrosion DBs. Distinct from:
  - COD            (experimental XRD crystal structures only, CC0)
  - MP / OMat24 / OQMD / AFLOW / NOMAD / GNoME (DFT predictions only)
  - Catalysis-Hub  (DFT surface-reaction predictions only)
NIMS MatNavi carries BOTH experimental and computed records — the adapter
validator enforces the `record_type` tag so the two flavours cannot be
conflated silently.

Two paths:
  1. Offline (`--selftest`): load `cache/sample_record.json`, validate schema
     (nims_id non-empty, composition_wt_pct sums ~100 %, record_type tag
     present and indicates measurement OR prediction unambiguously), emit
     sentinel. Always offline; deterministic.
  2. Live (`--query "SS304"`, optional): if stdlib `urllib.request`
     reachability is allowed, hit the MatNavi search HTML endpoint. NOT
     exercised in --selftest. Polite cadence ≥ 3 s observed; identifies
     itself with a User-Agent. MatNavi has no public REST/JSON API as of
     2024 — full Creep / Fatigue Data Sheet series remain account-gated.

The selftest never hits the network. The cache fixture is bundled.

It only validates schema + passes through. Mechanical / creep / corrosion
values are vendor / NIMS-lab MEASUREMENTS with their own published scatter
(mill-cert ± 5-10 % typical; multi-decade creep series with documented
statistics) — clearly labelled in adapter output and SOURCES.md.

Optional dep: none (stdlib only — `urllib.request` for the live path).
License: MIT (hexa-matter Phase J.3 adapter; NIMS open-data subsets are
         CC-BY 4.0, citation required to NIMS MatNavi 2024 release).
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

NIMS_SEARCH_URL = "https://mits.nims.go.jp/index_en.html"
USER_AGENT = "hexa-matter/0.1 (+https://github.com/dancinlab/hexa-matter) absorption_bridge/nims_mats"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_nims_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate a NIMS MatNavi record (or fixture).

    Required fields: nims_id (str), material_class, designation,
    standard_refs (list), composition_wt_pct (dict, sums ~100),
    test_condition, record_type (str must start with `experimental_` or
    `computed_`), record_type_note, publication.

    Honest C3: NIMS carries BOTH experimental and computed records. The
    validator REQUIRES `record_type` to start with `experimental_` or
    `computed_` so a downstream consumer cannot silently treat a DFT
    prediction as a measurement (or vice versa).
    """
    required = [
        "nims_id",
        "material_class",
        "designation",
        "standard_refs",
        "composition_wt_pct",
        "test_condition",
        "record_type",
        "record_type_note",
        "publication",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["nims_id"], str) or not rec["nims_id"].strip():
        return False, f"nims_id not non-empty string: {rec.get('nims_id')!r}"
    if not isinstance(rec["standard_refs"], list) or not rec["standard_refs"]:
        return False, f"standard_refs not non-empty list: {rec.get('standard_refs')!r}"
    comp = rec["composition_wt_pct"]
    if not isinstance(comp, dict) or not comp:
        return False, f"composition_wt_pct not non-empty dict"
    total = sum(v for v in comp.values() if isinstance(v, (int, float)))
    # Mill-cert typical tolerance — main elements sum 99-101; trace residuals allowed.
    if total < 95.0 or total > 101.5:
        return False, f"composition_wt_pct sum {total:.2f} outside [95, 101.5] window"
    rtype = str(rec.get("record_type", "")).lower()
    if not (rtype.startswith("experimental_") or rtype.startswith("computed_")):
        return False, (
            f"record_type={rtype!r} does not start with 'experimental_' or 'computed_'; "
            "NIMS MatNavi carries BOTH — record_type tag is required so prediction "
            "and measurement records cannot be conflated"
        )
    rnote = str(rec.get("record_type_note", "")).lower()
    if rtype.startswith("experimental_"):
        if "measure" not in rnote and "experimental" not in rnote and "measured" not in rnote:
            return False, (
                f"record_type_note for experimental record must mention measurement; "
                f"got {rnote!r}"
            )
    if rtype.startswith("computed_"):
        if "predict" not in rnote and "dft" not in rnote and "calphad" not in rnote and "comput" not in rnote:
            return False, (
                f"record_type_note for computed record must mention prediction/DFT/CALPHAD; "
                f"got {rnote!r}"
            )
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    """Deterministic md5 stamp for cache filename."""
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def fetch_search_live(query: str, timeout: float = 10.0) -> str:
    """Live search-page fetch. NOT exercised in --selftest.

    MatNavi has no public REST API as of 2024 — this just retrieves the
    landing page HTML. Real workflow is web-search → per-record HTML/PDF
    (often account-gated). The polite cadence (≥ 3 s) is the caller's
    responsibility.
    """
    url = NIMS_SEARCH_URL  # MatNavi has no JSON REST; landing-page HTML only here.
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_NIMS_MATS_SEARCH_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_NIMS_MATS_SEARCH_SMOKE__ FAIL")
        return 1

    ok, reason = validate_nims_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_NIMS_MATS_SEARCH_SMOKE__ FAIL")
        return 1
    mech = rec.get("mechanical_properties", {})
    print(
        f"  PASS: fixture schema OK "
        f"(nims_id={rec['nims_id']}, designation={rec['designation']}, "
        f"YS={mech.get('yield_strength_MPa')} MPa, UTS={mech.get('ultimate_tensile_strength_MPa')} MPa)"
    )

    # Honesty preservation — surface MEASUREMENT vs PREDICTION distinction
    # in adapter output, per bridge rule #4 ("predictions ≠ measurements").
    rtype = rec["record_type"]
    if rtype.startswith("experimental_"):
        print(
            "applied; mill-cert ± 5-10 % typical scatter authoritative)"
        )
    else:
        print(
            "applied; DFT/CALPHAD systematic error bars per source authoritative)"
        )
    print(
        "  NOTE: NIMS MatNavi carries BOTH experimental + computed records; "
        "validator enforces record_type tag so they cannot be silently conflated"
    )
    print(
        "  NOTE: live web-search path https://mits.nims.go.jp/ is "
        "OUT-OF-SCOPE for selftest (per NO LIVE API CALLS rule); MatNavi has "
        "no public REST/JSON — per-record HTML/PDF often account-gated"
    )

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_NIMS_MATS_SEARCH_SMOKE__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument(
        "--query",
        type=str,
        default=None,
        help="NIMS MatNavi search query (free text, e.g. 'SS304'). LIVE fetch; not used in --selftest.",
    )
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.query:
        try:
            html = fetch_search_live(args.query)
        except urllib.error.URLError as e:
            print(
                f"error: live NIMS MatNavi fetch failed for query={args.query!r}: {e}",
                file=sys.stderr,
            )
            return 2
        sys.stdout.write(html)
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
