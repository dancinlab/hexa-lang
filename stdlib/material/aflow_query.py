#!/usr/bin/env python3
# aflow_query.py — `material + query` AFLOW AFLUX REST thin adapter (D72/N6.x).
#
# RTSC.md §9.4 + §9.5 N6 cohort sibling — DFT-derived structure / spacegroup /
# formation-enthalpy ingest from the AFLOW (Automatic FLOW for Materials
# Discovery) library (Curtarolo et al., Comput. Mater. Sci. 58, 218, 2012).
# Companion to MP, OQMD (`oqmd_query.py`), COD (`cod_query.py`): same record
# shape, different DB.
#
# Source endpoint (no API key required for the public AFLUX REST):
#   - https://aflow.org/API/aflux/?<matchbook>,$paging(<page>,<n>)
#
# AFLUX query language (verified live 2026-05-23):
#   - matchbook clauses are *comma*-separated (NOT `&`); directives are
#     *dollar-prefixed* (`$paging`). http://aflow.org/API/... 301-redirects
#     to https — urllib follows GET redirects transparently.
#   - `$paging(P,N)` (TWO args) = page P, N rows per page → returns a JSON
#     *list* `[{...}]`. `$paging(N)` (ONE arg) means page N (default ~64
#     rows/page) — NOT "N rows"; high single-arg values silently return
#     `[]`. We always emit the two-arg `$paging(1,<n>)` form for "first n".
#   - bare `paging(...)` (no `$`) returns an *object* keyed `"i of TOTAL"`;
#     we avoid it — `$paging` gives the cleaner list shape.
#   - property names listed as bare clauses (e.g. `Egap`) are returned as
#     keys in each row (null when not stored); they do NOT act as
#     non-null filters in the two-arg `$paging` list mode.
#   - `species(A,B),nspecies(N)` is the reliable formula path. `compound(X)`
#     expects AFLOW's sorted element-count spelling (e.g. `B2Mg1`), so
#     `compound(MgB2)` returns `[]` — we prefer the species form.
#
# D72: thin adapter — GET + normalize + JSON dump, no math, no kernel share.
# D80: external-api gate when the call lands; external-api-failed on any
#      non-2xx / network / JSON-decode failure.
# g3:  absorbed = false 영원히 — AFLOW values are DFT-computed (PBE-GGA), NOT
#      measured (gap underestimation, ±0.1 eV/atom ΔH_f). Tc / λ / ω_log are
#      NOT in the AFLUX schema. RTSC.md §9 honest 한계 stance.
#
# License: the AFLUX REST is public + unauthenticated, but AFLOW requests the
# primary citation for downstream use (Curtarolo 2012). The dedicated license
# page (https://aflow.org/license/) returned 404 at build time (verified
# 2026-05-23), so we take the conservative `academic-cite-required` stance and
# propagate attribution through the `attribution`/`citations` fields. If
# clarified terms surface, update `license` + attribution in lockstep.

from __future__ import annotations

import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


AFLUX_ENDPOINT = "https://aflow.org/API/aflux/"
DEFAULT_TIMEOUT_S = 30.0
DEFAULT_PAGING = 10  # courtesy cap — shared AFLOW infra; keep batches small

# Property fields appended to every matchbook so rows carry observables, not
# just identifiers. Each becomes a row key (null when not stored). Verified
# safe (non-filtering) under the two-arg `$paging` list mode.
DEFAULT_PROPERTY_FIELDS = (
    "enthalpy_formation_atom",
    "Egap",
    "energy_atom",
    "density",
    "spacegroup_relax",
)


# ─── HTTP GET (stdlib only — no requests dep) ───────────────────────────


def _http_get_json(url: str, timeout_s: float) -> tuple[Any, str | None]:
    """Return (parsed_json, error_string). Never raises."""
    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "hexa-lang/aflow_query (D72/N6.x)"}
        )
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            status = getattr(resp, "status", None) or resp.getcode()
            if status is None or not (200 <= int(status) < 300):
                return None, f"AFLOW HTTP non-2xx: status={status}"
            body = resp.read().decode("utf-8", errors="replace")
        try:
            return json.loads(body), None
        except json.JSONDecodeError as je:
            return None, f"AFLOW response JSON decode failed: {je}"
    except urllib.error.HTTPError as he:
        return None, f"AFLOW HTTPError: {he.code} {he.reason}"
    except urllib.error.URLError as ue:
        return None, f"AFLOW URLError: {ue.reason}"
    except TimeoutError as te:
        return None, f"AFLOW timeout: {te}"
    except Exception as e:  # pragma: no cover — unexpected
        return None, f"AFLOW GET error: {type(e).__name__}: {e}"


# ─── family classification (RTSC.md §8.2 enum — mirrors mp/oqmd/cod) ────


def _classify_family(formula: str) -> str:
    f = formula.replace(" ", "")
    fl = f.lower()
    if ("pb10" in fl or "pb_10" in fl) and "p" in fl and "o" in fl:
        return "apatite-class claim-only (hypothetical · NOT replicated)"
    if "mgb2" in fl or fl == "mgb_2":
        return "mgb2 (replicated 2001~)"
    if f in {"H3S", "LaH10", "CaH6", "ScH9", "YH6"}:
        return "heavy-hydride (≥GPa pressure · device-impossible)"
    if "yba2cu3o" in fl or "rebco" in fl:
        return "hts-cuprate (REBCO · replicated 1986~)"
    if "bi" in fl and "cu" in fl and "o" in fl:
        return "hts-cuprate (BSCCO family)"
    if "fese" in fl or "fease" in fl or "feas" in fl or "bafe2as2" in fl:
        return "iron-based-sc (FeSC · replicated 2008~)"
    if f in {"NbTi", "Nb3Sn", "Nb3Ge"}:
        return "lts (low-Tc · industry mature)"
    return "unclassified (not in RTSC §8.2 candidate matrix)"


# ─── formula → AFLUX matchbook translation ──────────────────────────────


_ELEMENT_TOKEN_RX = re.compile(r"([A-Z][a-z]?)(\d*)")


def _parse_formula_to_elements(formula: str) -> list[str]:
    """Best-effort element-symbol extraction (first-seen order). Returns []
    when the input looks like a raw AFLUX expression rather than a formula."""
    if not formula or any(c in formula for c in "()$,"):
        return []
    elements: list[str] = []
    seen: set[str] = set()
    cursor = 0
    s = formula.replace(" ", "")
    while cursor < len(s):
        m = _ELEMENT_TOKEN_RX.match(s, cursor)
        if not m or not m.group(1):
            return []
        sym = m.group(1)
        if sym not in seen:
            seen.add(sym)
            elements.append(sym)
        cursor = m.end()
    return elements


def _build_matchbook(formula_or_expr: str, paging: int) -> tuple[str, str]:
    """Return (matchbook_str, query_kind in species-set|compound|raw-expr)."""
    props = ",".join(DEFAULT_PROPERTY_FIELDS)
    page_clause = f"$paging(1,{paging})"  # two-arg: page 1, `paging` rows
    elements = _parse_formula_to_elements(formula_or_expr)
    if elements:
        species_clause = "species(" + ",".join(sorted(elements)) + ")"
        nspecies_clause = f"nspecies({len(elements)})"
        mb = f"{species_clause},{nspecies_clause},{props},{page_clause}"
        return mb, "species-set"
    if any(c in formula_or_expr for c in "()$"):
        # Caller hand-built an AFLUX matchbook — append paging if absent.
        suffix = "" if "paging" in formula_or_expr else f",{page_clause}"
        return f"{formula_or_expr}{suffix}", "raw-expr"
    return f"compound({formula_or_expr}),{props},{page_clause}", "compound"


# ─── AFLOW response normalization ───────────────────────────────────────


def _normalize_aflow_entry(entry: dict) -> dict:
    """Project an AFLUX row into the demiurge-consumer shape; honest null for
    missing fields. We never invent values."""
    return {
        "auid": entry.get("auid"),
        "aurl": entry.get("aurl"),
        "compound": entry.get("compound"),
        "spacegroup_relax": entry.get("spacegroup_relax"),
        "Pearson_symbol_relax": entry.get("Pearson_symbol_relax"),
        "species": entry.get("species"),
        "nspecies": entry.get("nspecies"),
        "energy_atom_eV": entry.get("energy_atom"),
        "band_gap_eV": entry.get("Egap"),
        "enthalpy_formation_atom_eV": entry.get("enthalpy_formation_atom"),
        "density_g_cm3": entry.get("density"),
    }


def _coerce_rows(payload: Any) -> tuple[list[dict], str | None, bool]:
    """Normalize the AFLUX payload to rows. Returns (rows, drift_reason,
    failed). `$paging(P,N)` yields a list; bare-paging yields an object
    keyed `"i of TOTAL"` — accept both so a directive change never masks
    real data as a failure (d2/d7)."""
    if isinstance(payload, list):
        data = payload
    elif isinstance(payload, dict):
        # bare-paging object form, or future `{data:[...]}` envelope.
        listish = (
            payload.get("data") or payload.get("results")
            or payload.get("entries")
        )
        data = listish if isinstance(listish, list) else list(payload.values())
    else:
        return [], "AFLOW response was neither list nor dict — schema drift.", True
    rows = [_normalize_aflow_entry(e) for e in data if isinstance(e, dict)]
    return rows, None, False


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, formula_or_expr: str, paging: int = DEFAULT_PAGING) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "Curtarolo et al. 2012, Comput. Mater. Sci. 58, 218 — 'AFLOW: An "
        "automatic framework for high-throughput materials discovery' "
        "(AFLOW primary citation).",
        "Curtarolo et al. 2012, Comput. Mater. Sci. 58, 227 — "
        "'AFLOWLIB.ORG: A distributed materials properties repository from "
        "high-throughput ab initio calculations'.",
        "Rose et al. 2017, Comput. Mater. Sci. 137, 362 — 'AFLUX: The LUX "
        "materials search API for the AFLOW data repositories' (AFLUX "
        "query-language primary).",
        "AFLOW REST entry — https://aflow.org/API/aflux/.",
        "RTSC.md §9.4 + §9.5 N6 cohort — additional-source-ingest expansion.",
    ]

    scope_caveats = [
        "(s1) DFT-derived (not measured) — AFLOW entries are PBE-GGA "
        "computed (same systematic biases as MP/OQMD: gap underestimation "
        "30-50%; ΔH_f ±0.1 eV/atom).",
        "(s2) `energy_atom` is total energy per atom (eV/atom); "
        "`enthalpy_formation_atom` is formation enthalpy per atom (eV/atom) "
        "when populated — many LIB2/LIB3 prototype entries carry null.",
        "(s3) Tc / λ / ω_log / μ* are NOT in AFLOW's AFLUX schema — el-ph "
        "coupling / phonon properties must be sourced separately "
        "(sim_adapter Tier 1 / QE+EPW Tier 0).",
        "(s4) absorbed=false for all AFLOW-derived rows — DFT ≠ "
        "measurement. RTSC.md §9 honest 한계 + §8.8 g3 stance.",
        "(s5) License page (https://aflow.org/license/) returned 404 at "
        "build time (verified 2026-05-23). Conservative stance: "
        "`academic-cite-required` per the Curtarolo 2012 citation request. "
        "If clarified terms surface, update license + attribution in "
        "lockstep.",
    ]

    matchbook, query_kind = _build_matchbook(formula_or_expr, paging)
    url = AFLUX_ENDPOINT + "?" + matchbook

    gate_type = "external-api"
    skipped_reason: str | None = None
    rows: list[dict] = []

    payload, err = _http_get_json(url, DEFAULT_TIMEOUT_S)
    if err is not None:
        gate_type, skipped_reason = "external-api-failed", err
    else:
        rows, drift, failed = _coerce_rows(payload)
        if failed:
            gate_type, skipped_reason = "external-api-failed", drift

    record = {
        "domain": "material",
        "verb": "query",
        "kind": "aflow_lookup",
        "stamp": stamp,
        "producer": "aflow_query@material-n6.x",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,            # DFT != measurement; never absorb (R4)
        "gate_type": gate_type,       # external-api | external-api-failed
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "formula_or_expr": formula_or_expr,
            "matchbook": matchbook,
            "query_kind": query_kind,  # species-set | compound | raw-expr
            "paging": paging,
            "family_classification": _classify_family(formula_or_expr),
        },
        "row_count": len(rows),
        "rows": rows,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "attribution": (
            "Data from the AFLOW library (https://aflow.org), accessed via "
            "the AFLUX REST API. Cite: Curtarolo et al. Comput. Mater. Sci. "
            "58, 218 (2012); 58, 227 (2012); Rose et al. Comput. Mater. Sci. "
            "137, 362 (2017)."
        ),
        "license": (
            "academic-cite-required (license page 404 at build time — see s5)"
        ),
        "provenance": {
            "source_url": url,
            "source_citation": (
                "Curtarolo et al. Comput. Mater. Sci. 58, 218 (2012)"
            ),
            "primary_refs": [
                "Comput. Mater. Sci. 58 218 (Curtarolo 2012) — AFLOW primary.",
                "Comput. Mater. Sci. 58 227 (Curtarolo 2012) — AFLOWLIB repo.",
                "Comput. Mater. Sci. 137 362 (Rose 2017) — AFLUX language.",
            ],
            "api_endpoints": [
                f"{AFLUX_ENDPOINT}?<matchbook>,$paging(<page>,<n>)  (no key)",
            ],
        },
        "rtsc_anchor": (
            "RTSC.md §9.4 + §9.5 N6 cohort — AFLOW AFLUX REST "
            "(DFT-derived sibling to MP/OQMD/COD)"
        ),
    }

    rec_path = out / f"material_query_aflow_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[material+query·aflow] wrote {rec_path}")
    print(
        f"  · formula_or_expr={formula_or_expr!r}  query_kind={query_kind!r}  "
        f"family={record['query']['family_classification']!r}"
    )
    print(f"  · matchbook={matchbook}")
    print(f"  · gate_type={gate_type}  row_count={len(rows)}")
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    else:
        for r in rows[:5]:
            print(
                f"    - auid={r.get('auid')}  compound={r.get('compound')}  "
                f"sg={r.get('spacegroup_relax')}  "
                f"ΔH_f={r.get('enthalpy_formation_atom_eV')} eV/at  "
                f"Egap={r.get('band_gap_eV')}"
            )
        if len(rows) > 5:
            print(f"    ... ({len(rows) - 5} more rows)")
    print(
        "[material+query·aflow] absorbed=false (DFT != measurement; "
        "RTSC.md §9 honest 한계 — AFLOW rows NEVER promote to absorbed=true)"
    )
    return 0


if __name__ == "__main__":
    argv = sys.argv
    out_dir = argv[1] if len(argv) > 1 else "/tmp/material_query_aflow"
    formula = argv[2] if len(argv) > 2 else "MgB2"
    paging_arg = int(argv[3]) if len(argv) > 3 else DEFAULT_PAGING
    sys.exit(main(out_dir, formula, paging_arg))
