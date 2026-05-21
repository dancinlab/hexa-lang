#!/usr/bin/env python3
# oqmd_query.py — `material + query` OQMD direct REST thin adapter (D72/N6.1).
#
# RTSC.md §9.4 + §9.5 N6 cohort sibling — DFT-derived formation energy /
# energy_above_hull / prototype / spacegroup ingest from the Open Quantum
# Materials Database (Saal et al., JOM 65, 1501, 2013). Companion to MP
# (`mp_query.py`); same shape, different DB.
#
# Source endpoint (no API key required for read-only REST):
#   - https://oqmd.org/oqmdapi/formationenergy?composition=<comp>
#
# Note on the query string: the §9.4 spec sketched
# `?filter=composition=<comp>` (DRF-style filter), but the live OQMD
# REST API uses bare `composition=<comp>` as the query parameter and
# 400s on the `filter=` prefix. We send the bare form. The HTTP
# endpoint also 301-redirects to HTTPS — urllib follows redirects by
# default for GET, so this is transparent.
#
# D72: thin adapter. No math; just GET + normalize + JSON dump. No kernel
#      promotion (no shared math with mp_query or sim_adapter).
# D80: external-api gate when the call lands; external-api-failed on any
#      non-2xx; install-gated only if stdlib http stack is unusable (rare).
# g3:  absorbed = false 영원히 — OQMD values are DFT-computed (PBE-GGA),
#      NOT experimentally measured. Same band-gap / formation-energy
#      caveats as MP. RTSC.md §9 honest 한계 stance.
#
# License: CC-BY-4.0 (OQMD attribution required — propagated in the
# `attribution` field of the emitted record).

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


OQMD_ENDPOINT = "https://oqmd.org/oqmdapi/formationenergy"
DEFAULT_TIMEOUT_S = 30.0


# ─── HTTP GET (stdlib only — no requests dep) ───────────────────────────


def _http_get_json(url: str, timeout_s: float) -> tuple[Any, str | None]:
    """Return (parsed_json, error_string). Never raises.

    Surfaces HTTP non-2xx + network errors as a clean error string so the
    caller can emit an `external-api-failed` skip record."""
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "hexa-lang/oqmd_query (D72/N6.1)"},
        )
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            status = getattr(resp, "status", None) or resp.getcode()
            if status is None or not (200 <= int(status) < 300):
                return None, (
                    f"OQMD HTTP non-2xx: status={status}"
                )
            body = resp.read().decode("utf-8", errors="replace")
        try:
            return json.loads(body), None
        except json.JSONDecodeError as je:
            return None, f"OQMD response JSON decode failed: {je}"
    except urllib.error.HTTPError as he:
        return None, f"OQMD HTTPError: {he.code} {he.reason}"
    except urllib.error.URLError as ue:
        return None, f"OQMD URLError: {ue.reason}"
    except TimeoutError as te:
        return None, f"OQMD timeout: {te}"
    except Exception as e:  # pragma: no cover — unexpected
        return None, f"OQMD GET error: {type(e).__name__}: {e}"


# ─── family classification (RTSC.md §8.2 enum — mirrors mp_query) ──────


def _classify_family(formula: str) -> str:
    f = formula.replace(" ", "")
    f_lower = f.lower()
    if (("pb10" in f_lower or "pb_10" in f_lower) and "p" in f_lower
            and "o" in f_lower):
        return "lk-99-family (hypothetical · NOT replicated)"
    if "mgb2" in f_lower or f_lower == "mgb_2":
        return "mgb2 (replicated 2001~)"
    if f in {"H3S", "LaH10", "CaH6", "ScH9", "YH6"}:
        return "heavy-hydride (≥GPa pressure · device-impossible)"
    if "yba2cu3o" in f_lower or "rebco" in f_lower:
        return "hts-cuprate (REBCO · replicated 1986~)"
    if "bi" in f_lower and "cu" in f_lower and "o" in f_lower:
        return "hts-cuprate (BSCCO family)"
    if ("fese" in f_lower or "fease" in f_lower
            or "feas" in f_lower or "bafe2as2" in f_lower):
        return "iron-based-sc (FeSC · replicated 2008~)"
    if f in {"NbTi", "Nb3Sn", "Nb3Ge"}:
        return "lts (low-Tc · industry mature)"
    return "unclassified (not in RTSC §8.2 candidate matrix)"


# ─── OQMD response normalization ────────────────────────────────────────


def _normalize_oqmd_entry(entry: dict) -> dict:
    """Project an OQMD formationenergy row into the demiurge-consumer shape.

    OQMD returns nested objects (calculation, composition, structure). We
    keep the headline scalars + a compact summary; honest null for missing
    fields."""
    # OQMD fields (per oqmdapi/formationenergy docs):
    #   entry_id · name · composition · spacegroup · prototype · ntypes
    #   natoms · volume · delta_e · stability · band_gap · icsd_id
    # `delta_e` is the formation energy per atom (eV/atom).
    return {
        "entry_id": entry.get("entry_id") or entry.get("id"),
        "name": entry.get("name"),
        "composition": entry.get("composition"),
        "formation_energy_eV_per_atom": entry.get("delta_e"),
        "delta_e": entry.get("delta_e"),
        "prototype": entry.get("prototype"),
        "spacegroup": entry.get("spacegroup"),
        "energy_above_hull_eV": entry.get("stability"),
        "band_gap_eV": entry.get("band_gap"),
        "natoms": entry.get("natoms"),
        "ntypes": entry.get("ntypes"),
        "volume_A3": entry.get("volume"),
        "icsd_id": entry.get("icsd_id"),
    }


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, formula_or_composition: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "Saal et al. 2013, JOM 65, 1501 — 'Materials Design and Discovery "
        "with High-Throughput Density Functional Theory: The Open Quantum "
        "Materials Database (OQMD)' (OQMD primary citation).",
        "Kirklin et al. 2015, npj Computational Materials 1, 15010 — "
        "'The Open Quantum Materials Database (OQMD): assessing the "
        "accuracy of DFT formation energies'.",
        "OQMD REST API — http://oqmd.org/static/docs/restful.html.",
        "RTSC.md §9.4 + §9.5 N6 cohort — additional-source-ingest expansion.",
    ]

    scope_caveats = [
        "(s1) DFT-derived (not measured) — OQMD entries are PBE-GGA "
        "computed formation energies / band gaps with the same systematic "
        "biases as MP (gap underestimation 30-50%; ΔH_f ±0.1 eV/atom).",
        "(s2) `delta_e` is per atom in eV/atom (OQMD convention); "
        "`stability` ≈ energy above the convex hull (eV/atom).",
        "(s3) Tc / λ / ω_log / μ* are NOT in OQMD — Tier 1 sim_adapter "
        "must source phonon coupling separately.",
        "(s4) absorbed=false for all OQMD-derived rows — DFT ≠ "
        "measurement. RTSC.md §9 honest 한계 + §8.8 g3 stance.",
    ]

    # Query — OQMD REST. No API key required, but CC-BY attribution
    # must follow the data anywhere it's used.
    composition_q = formula_or_composition.replace(" ", "")
    # Live OQMD REST: `?composition=<comp>` (NOT `?filter=composition=...`
    # — the latter 400s). See module header for context.
    url = (
        f"{OQMD_ENDPOINT}?composition="
        f"{urllib.parse.quote(composition_q, safe='')}"
    )

    gate_type = "external-api"
    skipped_reason: str | None = None
    rows: list[dict] = []
    raw_meta: dict | None = None

    payload, err = _http_get_json(url, DEFAULT_TIMEOUT_S)
    if err is not None:
        gate_type = "external-api-failed"
        skipped_reason = err
    else:
        # OQMDapi returns `{ "meta": {...}, "data": [...] }` (DRF style).
        # Be defensive — some endpoints return raw list.
        if isinstance(payload, dict):
            raw_meta = {
                k: payload.get(k)
                for k in ("meta", "links", "next", "previous")
                if k in payload
            }
            data = payload.get("data") or payload.get("results") or []
        elif isinstance(payload, list):
            data = payload
        else:
            data = []
            skipped_reason = (
                "OQMD response was neither object-with-data nor list — "
                "schema drift; emitting empty rows."
            )
            gate_type = "external-api-failed"
        if isinstance(data, list):
            for entry in data:
                if not isinstance(entry, dict):
                    continue
                rows.append(_normalize_oqmd_entry(entry))

    source_url = url

    record = {
        "domain": "material",
        "verb": "query",
        "kind": "oqmd_lookup",
        "stamp": stamp,
        "producer": "oqmd_query@material-n6.1",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,            # DFT ≠ measurement; never absorb (R4)
        "gate_type": gate_type,       # external-api | external-api-failed
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "formula_or_composition": formula_or_composition,
            "composition_normalized": composition_q,
            "family_classification": _classify_family(formula_or_composition),
        },
        "row_count": len(rows),
        "rows": rows,
        "raw_meta": raw_meta,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "attribution": (
            "Data from the Open Quantum Materials Database (OQMD), "
            "http://oqmd.org. Licensed CC-BY-4.0. Cite: "
            "Saal et al. JOM 65, 1501 (2013); Kirklin et al. npj Comp "
            "Materials 1, 15010 (2015)."
        ),
        "license": "CC-BY-4.0",
        "provenance": {
            "source_url": source_url,
            "source_citation": "Saal et al. JOM 65, 1501 (2013)",
            "primary_refs": [
                "JOM 65 1501 (Saal 2013) — OQMD primary.",
                "npj Comp Mater 1 15010 (Kirklin 2015) — OQMD accuracy.",
            ],
            "api_endpoints": [
                "https://oqmd.org/oqmdapi/formationenergy?composition=<comp>  (no key)",
            ],
        },
        "rtsc_anchor": (
            "RTSC.md §9.4 + §9.5 N6 cohort — OQMD direct REST "
            "(DFT-derived, formation-energy-focused sibling to MP)"
        ),
    }

    rec_path = out / f"material_query_oqmd_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[material+query·oqmd] wrote {rec_path}")
    print(
        f"  · composition={formula_or_composition!r}  "
        f"family={record['query']['family_classification']!r}"
    )
    print(f"  · gate_type={gate_type}  row_count={len(rows)}")
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    else:
        for r in rows[:5]:
            print(
                f"    - entry={r.get('entry_id')}  name={r.get('name')}  "
                f"ΔH_f={r.get('formation_energy_eV_per_atom')} eV/at  "
                f"prototype={r.get('prototype')}  "
                f"sg={r.get('spacegroup')}"
            )
        if len(rows) > 5:
            print(f"    ... ({len(rows) - 5} more rows)")
    print(
        "[material+query·oqmd] absorbed=false (DFT ≠ measurement; "
        "RTSC.md §9 honest 한계 — OQMD rows NEVER promote to absorbed=true)"
    )
    return 0


if __name__ == "__main__":
    argv = sys.argv
    out_dir = argv[1] if len(argv) > 1 else "/tmp/material_query_oqmd"
    composition = argv[2] if len(argv) > 2 else "MgB2"
    sys.exit(main(out_dir, composition))
