#!/usr/bin/env python3
# supercon_query.py — `material + query` NIMS SuperCon DB thin adapter (D72/N6.3).
#
# RTSC.md §9.4 + §9.5 N6 cohort sibling — NIMS (Japan) SuperCon Database
# ingest. Companion to MP / OQMD / COD; unlike the other three, SuperCon
# carries *literature-extracted Tc + composition + experimental
# conditions* — it's the closest thing to a measurement-anchored row, but
# it's still literature-extracted (not raw instrument readout). R4 still
# applies: absorbed=false until a raw measurement run is attached.
#
# Source endpoint:
#   - https://supercon.nims.go.jp/  — registration-required (free,
#     non-trivial). NO public REST API.
#
# Behavior:
#   - Default (no env var): emit honest skip with
#     gate_type=supercon-registration-required. Always exit 0.
#   - If $SUPERCON_CSV_PATH is set to a readable CSV file: parse it row-by-
#     row and emit a typed measurement record per row. gate_type stays
#     "external-api" (the user has provided the data); rows carry
#     absorbed=false (literature-extracted ≠ raw instrument).
#
# D72: thin adapter. Just argparse + CSV → JSON. No external HTTP.
# D80: gate_type ∈ {supercon-registration-required, external-api}.
# g3:  absorbed = false 영원히 — SuperCon entries are *literature-
#      extracted* Tc values (digitized from papers), NOT raw instrument
#      measurements. R4 invariant + RTSC.md §9 honest 한계.

from __future__ import annotations

import csv
import json
import os
import sys
import time
from pathlib import Path
from typing import Any


SUPERCON_HOME_URL = "https://supercon.nims.go.jp/"
ENV_CSV_PATH = "SUPERCON_CSV_PATH"


# ─── family classification (mirror sibling adapters) ────────────────────


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


# ─── CSV row normalization ──────────────────────────────────────────────


_NUMERIC_KEYS = {
    "tc", "tc_k", "tc_onset", "tc_zero", "tc_mid",
    "pressure", "pressure_gpa", "pressure_GPa",
    "field", "field_T", "field_t", "h_c2",
    "year", "doi_year",
}


def _maybe_float(s: str) -> float | str | None:
    if s is None:
        return None
    s_strip = s.strip()
    if not s_strip:
        return None
    try:
        return float(s_strip)
    except ValueError:
        return s_strip


def _normalize_csv_row(row: dict, formula_filter: str | None) -> dict | None:
    """Project a SuperCon-style CSV row to the demiurge consumer shape.

    SuperCon export columns vary across vintages; we keep raw_row for
    fidelity, and surface a few commonly-present canonical fields
    (formula / element / tc / pressure / reference). If formula_filter
    is given, drop rows whose formula doesn't match (case-insensitive,
    whitespace-stripped)."""
    raw = {k: (v.strip() if isinstance(v, str) else v) for k, v in row.items()}
    # Heuristic — find the formula column.
    formula_col = None
    for cand in ("formula", "Formula", "FORMULA", "element",
                 "Element", "composition", "Composition"):
        if cand in raw:
            formula_col = cand
            break
    formula_val = raw.get(formula_col) if formula_col else None
    if formula_filter is not None and formula_val is not None:
        if formula_val.replace(" ", "").lower() \
                != formula_filter.replace(" ", "").lower():
            return None
    # Heuristic — find Tc column.
    tc_val: Any = None
    tc_col_used = None
    for cand in ("tc", "Tc", "TC", "T_c", "Tc(K)", "tc_k", "Tc_K"):
        if cand in raw and raw[cand]:
            tc_val = _maybe_float(raw[cand])
            tc_col_used = cand
            break
    # Heuristic — pressure (GPa).
    pressure_val: Any = None
    for cand in ("pressure", "Pressure", "p_GPa", "pressure_GPa",
                 "Pressure(GPa)", "p"):
        if cand in raw and raw[cand]:
            pressure_val = _maybe_float(raw[cand])
            break
    # Reference / DOI heuristic.
    ref = None
    for cand in ("reference", "Reference", "doi", "DOI", "citation",
                 "Citation"):
        if cand in raw and raw[cand]:
            ref = raw[cand]
            break
    return {
        "formula": formula_val,
        "formula_column_used": formula_col,
        "tc_K": tc_val,
        "tc_column_used": tc_col_used,
        "pressure_GPa": pressure_val,
        "reference": ref,
        "raw_row": raw,
    }


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, formula: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "NIMS SuperCon Database — National Institute for Materials Science, "
        "Japan (2002~). https://supercon.nims.go.jp/.",
        "Stanev et al. 2018, npj Computational Materials 4, 29 — 'Machine "
        "learning modeling of superconducting critical temperature' "
        "(downstream user of SuperCon corpus).",
        "Hamidieh 2018, Comput. Mater. Sci. 154, 346 — 'A data-driven "
        "statistical model for predicting the critical temperature of a "
        "superconductor' (also uses SuperCon).",
        "RTSC.md §9.4 + §9.5 N6 cohort — additional-source-ingest expansion.",
    ]

    scope_caveats = [
        "(s1) literature-extracted ≠ raw instrument — SuperCon Tc values "
        "are digitized FROM published papers, NOT directly from "
        "instrument measurement runs. R4 absorbed=false applies.",
        "(s2) Tc definition varies row-to-row (Tc_onset vs Tc_midpoint vs "
        "Tc_zero); column ambiguity is preserved in `tc_column_used`.",
        "(s3) Composition strings are normalized inconsistently across "
        "vintages of the DB (spaces, subscript conventions); downstream "
        "must reconcile against MP/OQMD/COD formulas before joining.",
        "(s4) absorbed=false for all SuperCon rows — RTSC.md §9 honest "
        "한계 + §8.8 g3 stance. Promotion to absorbed=true requires a "
        "raw measurement attestation, not a literature digitization.",
    ]

    csv_path_env = os.environ.get(ENV_CSV_PATH)
    rows: list[dict] = []
    gate_type: str
    skipped_reason: str | None = None
    csv_source: str | None = None
    total_rows_scanned = 0
    filtered_out = 0

    if not csv_path_env:
        gate_type = "supercon-registration-required"
        skipped_reason = (
            "NIMS SuperCon DB requires free registration at "
            f"{SUPERCON_HOME_URL} ; no public REST API. Honest skip — "
            "adapter never automates registration. To ingest rows, "
            "download a CSV export from the DB and set "
            f"${ENV_CSV_PATH}=/path/to/supercon_export.csv."
        )
    else:
        csv_path = Path(csv_path_env).expanduser()
        if not csv_path.exists() or not csv_path.is_file():
            gate_type = "supercon-registration-required"
            skipped_reason = (
                f"${ENV_CSV_PATH}={csv_path_env!r} does not resolve to a "
                f"readable file. Honest skip — fix the path or unset to "
                f"return to registration-required default."
            )
        else:
            csv_source = str(csv_path)
            try:
                with csv_path.open("r", encoding="utf-8", errors="replace",
                                   newline="") as fh:
                    reader = csv.DictReader(fh)
                    for row in reader:
                        total_rows_scanned += 1
                        norm = _normalize_csv_row(row, formula)
                        if norm is None:
                            filtered_out += 1
                            continue
                        rows.append(norm)
                gate_type = "external-api"
            except Exception as e:
                gate_type = "supercon-registration-required"
                skipped_reason = (
                    f"CSV parse failed: {type(e).__name__}: {e}. "
                    f"Honest skip — falling back to "
                    f"registration-required default."
                )

    record = {
        "domain": "material",
        "verb": "query",
        "kind": "supercon_lookup",
        "stamp": stamp,
        "producer": "supercon_query@material-n6.3",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,            # literature-extracted ≠ raw (R4)
        "gate_type": gate_type,       # supercon-registration-required | external-api
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "formula": formula,
            "family_classification": _classify_family(formula),
            "csv_path_env_var": ENV_CSV_PATH,
            "csv_source": csv_source,
        },
        "csv_stats": {
            "total_rows_scanned": total_rows_scanned,
            "filtered_out_by_formula": filtered_out,
            "rows_emitted": len(rows),
        },
        "row_count": len(rows),
        "rows": rows,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "attribution": (
            "Data (when present) from the NIMS SuperCon Database, "
            f"{SUPERCON_HOME_URL}. Registration required. Cite the "
            "underlying experimental papers referenced in each row's "
            "`reference` field as well as NIMS for the curated DB."
        ),
        "license": (
            "NIMS SuperCon — registration-required; per-row underlying "
            "experimental papers carry their own licenses (typically "
            "publisher copyright; data points are facts and not "
            "copyrightable, but verbatim text is)."
        ),
        "provenance": {
            "source_url": SUPERCON_HOME_URL,
            "source_citation": (
                "NIMS SuperCon Database (2002~), supercon.nims.go.jp"
            ),
            "primary_refs": [
                "NIMS SuperCon DB (2002~) — primary curated corpus.",
                "npj Comp Mater 4 29 (Stanev 2018) — ML user of SuperCon.",
                "Comput Mater Sci 154 346 (Hamidieh 2018) — ML user.",
            ],
            "api_endpoints": [
                f"{SUPERCON_HOME_URL}  (web UI · registration required)",
                f"env: ${ENV_CSV_PATH}  (user-provided CSV import path)",
            ],
        },
        "rtsc_anchor": (
            "RTSC.md §9.4 + §9.5 N6 cohort — NIMS SuperCon register-only "
            "honest-skip sibling (literature-extracted Tc corpus)"
        ),
    }

    rec_path = out / f"material_query_supercon_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[material+query·supercon] wrote {rec_path}")
    print(
        f"  · formula={formula!r}  "
        f"family={record['query']['family_classification']!r}"
    )
    print(
        f"  · gate_type={gate_type}  row_count={len(rows)}  "
        f"csv_source={csv_source!r}"
    )
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    for r in rows[:5]:
        print(
            f"    - formula={r.get('formula')}  Tc={r.get('tc_K')} K  "
            f"P={r.get('pressure_GPa')} GPa  ref={r.get('reference')!r}"
        )
    if len(rows) > 5:
        print(f"    ... ({len(rows) - 5} more rows)")
    print(
        "[material+query·supercon] absorbed=false (literature-extracted "
        "≠ raw instrument; RTSC.md §9 honest 한계 — SuperCon rows NEVER "
        "promote to absorbed=true)"
    )
    return 0


if __name__ == "__main__":
    argv = sys.argv
    out_dir = argv[1] if len(argv) > 1 else "/tmp/material_query_supercon"
    formula = argv[2] if len(argv) > 2 else "MgB2"
    sys.exit(main(out_dir, formula))
