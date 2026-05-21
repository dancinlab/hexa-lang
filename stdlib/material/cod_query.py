#!/usr/bin/env python3
# cod_query.py — `material + query` COD CIF parser thin adapter (D72/N6.2).
#
# RTSC.md §9.4 + §9.5 N6 cohort sibling — Crystallography Open Database
# (Gražulis et al., J. Appl. Crystallogr. 42, 726, 2009) ingest. Companion
# to MP (`mp_query.py`) + OQMD (`oqmd_query.py`); same D72 shape but COD
# only carries *structure*, not derived properties.
#
# Source endpoints (no API key required; public-domain data):
#   - http://www.crystallography.net/cod/result?text=<comp>&format=csv
#       → CSV index of matching COD entries (col 1 = 7-digit COD ID)
#   - http://www.crystallography.net/cod/<id>.cif
#       → individual CIF (Crystallographic Information File)
#
# Note on the query: §9.4 sketched `result.php?formula=<comp>&format=lst`.
# That endpoint exists but `format=lst` returns an empty body for most
# queries, and `formula=` performs strict "- <space-separated> -" SQL
# LIKE matching that misses common formula spellings. Live behavior we
# observed: `/cod/result?text=<comp>&format=csv` returns real CSV rows
# with the COD ID in column 1. We use that. The §9 spec is permissive
# ("Or download CIF files directly via …/<id>.cif"); CIF download still
# follows the §9.4-listed URL.
#
# D72: thin adapter. CIF parsing is install-gated (pymatgen.Structure);
#      without pymatgen we still emit the COD-ID list + provenance.
# D80: external-api gate when the call lands; external-api-failed on any
#      network failure; install-gated when CIF parsing requested but
#      pymatgen is unavailable.
# g3:  absorbed = false 영원히 — COD entries are structure-only (no
#      derived properties, no measurement of bulk macro observables).
#      RTSC.md §9 honest 한계 stance.
#
# License: public domain (no attribution required, but cite the URL +
# COD paper for provenance).

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


COD_RESULT_ENDPOINT = "http://www.crystallography.net/cod/result"
COD_CIF_ENDPOINT = "http://www.crystallography.net/cod"
DEFAULT_TIMEOUT_S = 30.0
MAX_CIFS_TO_FETCH = 3  # courtesy cap — don't hammer COD


# ─── HTTP GET (stdlib only) ─────────────────────────────────────────────


def _http_get_text(url: str, timeout_s: float) -> tuple[str | None, str | None]:
    """Return (text_body, error_string). Never raises."""
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "hexa-lang/cod_query (D72/N6.2)"},
        )
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            status = getattr(resp, "status", None) or resp.getcode()
            if status is None or not (200 <= int(status) < 300):
                return None, f"COD HTTP non-2xx: status={status}"
            body = resp.read().decode("utf-8", errors="replace")
        return body, None
    except urllib.error.HTTPError as he:
        return None, f"COD HTTPError: {he.code} {he.reason}"
    except urllib.error.URLError as ue:
        return None, f"COD URLError: {ue.reason}"
    except TimeoutError as te:
        return None, f"COD timeout: {te}"
    except Exception as e:  # pragma: no cover
        return None, f"COD GET error: {type(e).__name__}: {e}"


# ─── pymatgen probe (install-gated CIF parse) ───────────────────────────


def _probe_pymatgen_structure():
    """Return (Structure_class, error_string)."""
    try:
        from pymatgen.core import Structure  # noqa: F401

        return Structure, None
    except ImportError as e:
        return None, f"pymatgen import failed: {e}"
    except Exception as e:  # pragma: no cover
        return None, f"pymatgen import error: {e}"


# ─── family classification (mirror mp_query / oqmd_query) ───────────────


def _classify_family(formula: str) -> str:
    f = formula.replace(" ", "")
    f_lower = f.lower()
    if (("pb10" in f_lower or "pb_10" in f_lower) and "p" in f_lower
            and "o" in f_lower):
        return "apatite-class claim-only (hypothetical · NOT replicated)"
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


# ─── COD result parsing ─────────────────────────────────────────────────


COD_ID_RX = re.compile(r"\b(\d{7})\b")  # COD IDs are 7-digit
# CSV-row leading-id pattern — COD CSV puts the file id as the first
# quoted column (e.g. `"7040397",...`). Use a leading-anchored regex so
# we don't accidentally pull a 7-digit value out of a later column.
COD_CSV_LEADING_ID_RX = re.compile(r'^"(\d{7})"')


def _extract_cod_ids(body: str) -> list[str]:
    """Parse COD CSV (or fallback text) and extract COD IDs in order.

    The CSV path (`/cod/result?text=<comp>&format=csv`) returns rows
    starting with a quoted 7-digit file id; we anchor on that. We also
    fall back to any 7-digit token elsewhere in the body, dedup, and
    preserve first-seen order."""
    ids: list[str] = []
    seen: set[str] = set()
    # First pass: CSV-anchored extraction (canonical).
    for line in body.splitlines():
        m = COD_CSV_LEADING_ID_RX.match(line)
        if m:
            cod_id = m.group(1)
            if cod_id not in seen:
                seen.add(cod_id)
                ids.append(cod_id)
    if ids:
        return ids
    # Fallback: any 7-digit token in the body (lst-format / HTML).
    for line in body.splitlines():
        if line.startswith("#"):
            continue
        for m in COD_ID_RX.finditer(line):
            cod_id = m.group(1)
            if cod_id not in seen:
                seen.add(cod_id)
                ids.append(cod_id)
    return ids


def _normalize_cif_structure(Structure, cif_text: str, cod_id: str) -> dict:
    """Parse a CIF via pymatgen and project to a compact summary row.
    On any parse error, return a row with structure=None + parse_error
    surfaced — never raise."""
    try:
        s = Structure.from_str(cif_text, fmt="cif")
        lattice = s.lattice
        return {
            "cod_id": cod_id,
            "formula_reduced": s.composition.reduced_formula,
            "formula_full": str(s.composition),
            "nsites": int(s.num_sites),
            "lattice": {
                "a": float(lattice.a),
                "b": float(lattice.b),
                "c": float(lattice.c),
                "alpha": float(lattice.alpha),
                "beta": float(lattice.beta),
                "gamma": float(lattice.gamma),
                "volume_A3": float(lattice.volume),
            },
            "spacegroup": (
                s.get_space_group_info()[0]
                if hasattr(s, "get_space_group_info") else None
            ),
            "density_g_cm3": float(s.density) if s.density is not None else None,
            "parse_error": None,
        }
    except Exception as e:
        return {
            "cod_id": cod_id,
            "formula_reduced": None,
            "formula_full": None,
            "nsites": None,
            "lattice": None,
            "spacegroup": None,
            "density_g_cm3": None,
            "parse_error": f"CIF parse failed: {type(e).__name__}: {e}",
        }


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, formula: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "Gražulis et al. 2009, J. Appl. Crystallogr. 42, 726 — "
        "'Crystallography Open Database — an open-access collection of "
        "crystal structures' (COD primary citation).",
        "Gražulis et al. 2012, Nucleic Acids Res. 40, D420 — "
        "'Crystallography Open Database (COD): an open-access collection "
        "of crystal structures and platform for world-wide collaboration'.",
        "COD home — http://www.crystallography.net/cod/.",
        "RTSC.md §9.4 + §9.5 N6 cohort — additional-source-ingest expansion.",
    ]

    scope_caveats = [
        "(s1) structure-only-no-property — COD entries carry crystal "
        "structures (lattice, sites, occupancies) ONLY. No formation "
        "energy, no band gap, no Tc, no electron-phonon coupling. "
        "Downstream consumers must NOT infer derived properties from "
        "COD rows alone.",
        "(s2) Structures are *experimentally determined* (XRD / neutron "
        "diffraction in most cases) — but a structure measurement is NOT "
        "a Tc / transport measurement. R4 absorbed=false still applies "
        "for any RTSC superconductivity claim.",
        "(s3) Multiple COD IDs may exist per formula (different polymorphs "
        "/ different refinements). Caller decides which to absorb.",
        "(s4) absorbed=false for all COD-derived rows in the RTSC "
        "pipeline — RTSC.md §9 honest 한계 + §8.8 g3 stance.",
    ]

    gate_type = "external-api"
    skipped_reason: str | None = None
    cod_ids: list[str] = []
    rows: list[dict] = []
    cif_parse_backend: str | None = None
    cif_parse_warning: str | None = None

    # Step 1: hit the text-search endpoint with CSV output. See module
    # header for why we use `text=` rather than the §9.4-sketched
    # `formula=` query — `text=` matches common formula spellings; the
    # strict `formula=` SQL-LIKE matcher misses most inputs.
    composition_q = formula.replace(" ", "")
    result_url = (
        f"{COD_RESULT_ENDPOINT}?text="
        f"{urllib.parse.quote(composition_q, safe='')}"
        f"&format=csv"
    )
    body, err = _http_get_text(result_url, DEFAULT_TIMEOUT_S)
    if err is not None:
        gate_type = "external-api-failed"
        skipped_reason = err
    else:
        cod_ids = _extract_cod_ids(body)

    # Step 2: if we have COD IDs and pymatgen is available, fetch + parse
    # up to MAX_CIFS_TO_FETCH CIFs.
    if cod_ids and gate_type == "external-api":
        Structure, import_err = _probe_pymatgen_structure()
        if Structure is None:
            cif_parse_backend = None
            cif_parse_warning = (
                f"pymatgen not installed — emitting COD-ID list only. "
                f"Install: `pip install pymatgen` for full CIF parse. "
                f"({import_err})"
            )
            # Emit ID-only rows so downstream can still cite provenance.
            for cod_id in cod_ids[:MAX_CIFS_TO_FETCH]:
                rows.append({
                    "cod_id": cod_id,
                    "formula_reduced": None,
                    "formula_full": None,
                    "nsites": None,
                    "lattice": None,
                    "spacegroup": None,
                    "density_g_cm3": None,
                    "parse_error": "pymatgen not installed — id-only row",
                    "cif_url": f"{COD_CIF_ENDPOINT}/{cod_id}.cif",
                })
        else:
            cif_parse_backend = "pymatgen.core.Structure.from_str"
            for cod_id in cod_ids[:MAX_CIFS_TO_FETCH]:
                cif_url = f"{COD_CIF_ENDPOINT}/{cod_id}.cif"
                cif_text, cif_err = _http_get_text(cif_url, DEFAULT_TIMEOUT_S)
                if cif_err is not None or cif_text is None:
                    rows.append({
                        "cod_id": cod_id,
                        "formula_reduced": None,
                        "formula_full": None,
                        "nsites": None,
                        "lattice": None,
                        "spacegroup": None,
                        "density_g_cm3": None,
                        "parse_error": (
                            cif_err or "empty CIF body"
                        ),
                        "cif_url": cif_url,
                    })
                    continue
                row = _normalize_cif_structure(Structure, cif_text, cod_id)
                row["cif_url"] = cif_url
                rows.append(row)

    record = {
        "domain": "material",
        "verb": "query",
        "kind": "cod_lookup",
        "stamp": stamp,
        "producer": "cod_query@material-n6.2",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,            # structure ≠ Tc measurement (R4)
        "gate_type": gate_type,       # external-api | external-api-failed | install-gated
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "formula": formula,
            "composition_normalized": composition_q,
            "family_classification": _classify_family(formula),
        },
        "cod_id_count": len(cod_ids),
        "cod_ids": cod_ids,
        "row_count": len(rows),
        "rows": rows,
        "cif_parse_backend": cif_parse_backend,
        "cif_parse_warning": cif_parse_warning,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "attribution": (
            "Crystal structures from the Crystallography Open Database "
            "(COD), http://www.crystallography.net/cod/. Public domain. "
            "Cite: Gražulis et al. J. Appl. Crystallogr. 42, 726 (2009)."
        ),
        "license": "public-domain",
        "provenance": {
            "source_url": result_url,
            "source_citation": (
                "Gražulis et al. J. Appl. Crystallogr. 42, 726 (2009)"
            ),
            "primary_refs": [
                "J. Appl. Crystallogr. 42 726 (Gražulis 2009) — COD primary.",
                "Nucleic Acids Res. 40 D420 (Gražulis 2012) — COD platform.",
            ],
            "api_endpoints": [
                f"{COD_RESULT_ENDPOINT}?text=<comp>&format=csv",
                f"{COD_CIF_ENDPOINT}/<cod_id>.cif",
            ],
        },
        "rtsc_anchor": (
            "RTSC.md §9.4 + §9.5 N6 cohort — COD CIF parser "
            "(experimental-structure-only sibling to MP/OQMD)"
        ),
    }

    rec_path = out / f"material_query_cod_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[material+query·cod] wrote {rec_path}")
    print(
        f"  · formula={formula!r}  "
        f"family={record['query']['family_classification']!r}"
    )
    print(
        f"  · gate_type={gate_type}  cod_id_count={len(cod_ids)}  "
        f"row_count={len(rows)}"
    )
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    if cif_parse_warning:
        print(f"  · cif_parse_warning: {cif_parse_warning}")
    if rows:
        for r in rows[:3]:
            print(
                f"    - cod={r.get('cod_id')}  "
                f"reduced={r.get('formula_reduced')}  "
                f"sg={r.get('spacegroup')}  "
                f"nsites={r.get('nsites')}"
            )
    print(
        "[material+query·cod] absorbed=false (structure-only-no-property; "
        "RTSC.md §9 honest 한계 — COD rows NEVER promote to absorbed=true "
        "for Tc claims)"
    )
    return 0


if __name__ == "__main__":
    argv = sys.argv
    out_dir = argv[1] if len(argv) > 1 else "/tmp/material_query_cod"
    formula = argv[2] if len(argv) > 2 else "MgB2"
    sys.exit(main(out_dir, formula))
