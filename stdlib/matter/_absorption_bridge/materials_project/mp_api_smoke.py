#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mp_api_smoke.py — Materials Project API adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live API works via mp-api SDK
OR a stdlib-only REST fallback).

Three paths:
  1. Offline (`--selftest`): load `cache/sample_response.json`, validate schema
     (material_id, formula, structure.lattice.a, etc.), emit sentinel. Always
     offline; deterministic. NEVER hits the network.
  2. Live (`--mp-id mp-XXX`): fetch a record by Materials Project ID. Uses the
     `mp-api` SDK if it is importable AND usable; otherwise falls back to a
     stdlib-only `urllib` call against the MP REST summary endpoint.
  3. Live (`--formula <formula>`): composition search (e.g. `FeCo2Ge`). Same
     SDK-or-stdlib-REST resolution as path 2.

Both live paths require the `MP_API_KEY` env var. NOT exercised in --selftest
(per `NO LIVE API CALLS in selftest` rule from INIT.md Phase G).

Why a stdlib fallback exists (per bridge rule g5.1 — stdlib fallback): the
`mp-api` SDK pulls `emmet-core`, which on some environments imports symbols
absent from the locally-installed `pymatgen` (observed 2026-05-17: emmet-core
0.84.6rc4 imports `SymmetryUndeterminedError`, absent in pymatgen 2024.8.9 on
Python 3.9). The stdlib-REST path keeps the adapter functional regardless.

Optional dep: mp-api >= 0.41.0  (`pip install mp-api`) — NOT required; the
stdlib `urllib` fallback works on stock Python 3.9+.
License: MIT (hexa-matter Phase G). MP data itself: CC-BY 4.0 — see SOURCES.md.
"""

from __future__ import annotations
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_response.json"

MP_REST_BASE = "https://api.materialsproject.org"
# Default fields pulled by the live paths — magnetism + stability oriented.
_LIVE_FIELDS = [
    "material_id", "formula_pretty", "is_magnetic", "total_magnetization",
    "ordering", "energy_above_hull", "is_stable", "symmetry",
]


def _have_mp_api() -> bool:
    """True if the `mp_api` top-level package can be imported at all."""
    try:
        import mp_api  # noqa: F401
        return True
    except ImportError:
        return False


def _mp_api_usable() -> bool:
    """True only if `MPRester` actually imports.

    Distinct from `_have_mp_api`: the `mp_api` package can be present yet
    `MPRester` still fail to import because of an `emmet-core` <-> `pymatgen`
    version conflict. Catch broadly — any import-time exception means the SDK
    path is not usable and the stdlib-REST fallback must be taken.
    """
    try:
        from mp_api.client import MPRester  # noqa: F401
        return True
    except Exception:
        return False


def _rest_summary_query(
    key: str,
    *,
    material_ids: list[str] | None = None,
    formula: str | None = None,
    fields: list[str] | None = None,
    limit: int = 20,
) -> list[dict]:
    """Query the MP `materials/summary` endpoint via stdlib `urllib` only.

    No `mp-api` / `pymatgen` dependency. Returns the `data` list from the JSON
    response. Raises `urllib.error.*` / `OSError` on transport failure.
    """
    import urllib.request
    import urllib.parse

    params: dict[str, str] = {}
    if material_ids:
        params["material_ids"] = ",".join(material_ids)
    if formula:
        params["formula"] = formula
    if fields:
        params["_fields"] = ",".join(fields)
    params["_limit"] = str(limit)

    url = f"{MP_REST_BASE}/materials/summary/?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(
        url,
        headers={"X-API-KEY": key, "User-Agent": "hexa-matter-absorption-bridge/1.0"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:  # noqa: S310 (trusted host)
        payload = json.load(resp)
    return payload.get("data", [])


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    """Load the bundled sample fixture. Offline-only."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_mp_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate a Materials Project record (or fixture).

    Returns (ok, reason). Required fields: material_id, formula_pretty,
    elements, nsites, structure.lattice.a.
    """
    required = ["material_id", "formula_pretty", "elements", "nsites", "structure"]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"
    if not isinstance(rec["material_id"], str) or not rec["material_id"].startswith("mp-"):
        return False, f"material_id not mp-XXX format: {rec.get('material_id')!r}"
    if "lattice" not in rec["structure"] or "a" not in rec["structure"]["lattice"]:
        return False, "structure.lattice.a missing"
    a = rec["structure"]["lattice"]["a"]
    if not isinstance(a, (int, float)) or a <= 0:
        return False, f"structure.lattice.a not positive: {a!r}"
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    """Deterministic md5 stamp for cache filename."""
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_MP_API_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_MP_API_SMOKE__ FAIL")
        return 1

    ok, reason = validate_mp_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_MP_API_SMOKE__ FAIL")
        return 1
    print(f"  PASS: fixture schema OK (material_id={rec['material_id']}, a={rec['structure']['lattice']['a']} Å)")

    # Honest C3: the live MP path is intentionally NOT exercised in selftest.
    if _have_mp_api():
        if _mp_api_usable():
            print("  NOTE: mp-api installed + usable; live API OUT-OF-SCOPE for selftest (offline determinism)")
        else:
            print("  NOTE: mp-api installed but MPRester import fails (emmet-core/pymatgen conflict); stdlib-REST fallback covers the live path")
    else:
        print("  NOTE: mp-api not installed; stdlib-REST fallback covers the live path (no live call in selftest)")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("__HEXA_MATTER_MP_API_SMOKE__ PASS")
    return 0


def _live_query(*, mp_id: str | None, formula: str | None) -> int:
    """Live MP lookup. mp-api SDK if usable, else stdlib-REST fallback.

    Not exercised in --selftest (NO LIVE API CALLS rule).
    """
    key = os.environ.get("MP_API_KEY")
    if not key:
        print("error: MP_API_KEY env var not set", file=sys.stderr)
        return 2

    docs: list[dict] | None = None
    used = ""

    # Path A — mp-api SDK, only if MPRester actually imports.
    if _mp_api_usable():
        try:
            from mp_api.client import MPRester  # type: ignore
            with MPRester(key) as mpr:
                if mp_id:
                    res = mpr.materials.summary.search(material_ids=[mp_id], fields=_LIVE_FIELDS)
                else:
                    res = mpr.materials.summary.search(formula=formula, fields=_LIVE_FIELDS)
                docs = [d.dict() if hasattr(d, "dict") else dict(d) for d in res]
                used = "mp-api SDK"
        except Exception as e:  # noqa: BLE001 — SDK runtime failure → fall back
            print(f"  NOTE: mp-api SDK unusable at runtime ({type(e).__name__}: {e}); "
                  f"falling back to stdlib REST", file=sys.stderr)

    # Path B — stdlib-only REST fallback.
    if docs is None:
        try:
            docs = _rest_summary_query(
                key,
                material_ids=[mp_id] if mp_id else None,
                formula=formula,
                fields=_LIVE_FIELDS,
            )
            used = "stdlib REST fallback"
        except Exception as e:  # noqa: BLE001
            print(f"error: MP REST query failed ({type(e).__name__}: {e})", file=sys.stderr)
            return 2

    target = mp_id if mp_id else f"formula={formula}"
    print(f"# MP query [{target}] via {used} — {len(docs)} record(s)")
    print("# Materials Project DFT values are COMPUTED PREDICTIONS, not measurements (CC-BY 4.0; see SOURCES.md)")
    print(json.dumps(docs, indent=2, default=str))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--mp-id", default=None, help="Materials Project ID (e.g. mp-149); requires MP_API_KEY")
    p.add_argument("--formula", default=None, help="composition search (e.g. FeCo2Ge); requires MP_API_KEY")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.mp_id and args.formula:
        print("error: pass only one of --mp-id / --formula", file=sys.stderr)
        return 2
    if args.mp_id or args.formula:
        return _live_query(mp_id=args.mp_id, formula=args.formula)

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
