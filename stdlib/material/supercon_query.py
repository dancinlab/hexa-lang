#!/usr/bin/env python3
# supercon_query.py — `material + query` NIMS SuperCon (MDR) thin adapter (MP P2.3).
#
# MP.md Phase 2 §P2.3 sibling — NIMS (Japan) SuperCon Database ingest, the
# experimental-Tc corpus companion to MP / OQMD / COD / AFLOW. Same record
# shape, different DB. Unlike the other four (all structure / DFT-derived),
# SuperCon carries *literature-extracted measured Tc* + composition +
# experimental conditions — the closest sibling to a measurement-anchored
# row. R4 still applies (see g3 / d6 below): absorbed=false 영구.
#
# Source endpoint (no API key, no registration — public CC-BY-4.0):
#   NIMS migrated SuperCon to the Materials Data Repository (MDR) in 2022.
#   The legacy register-only `supercon.nims.go.jp` web UI is superseded by a
#   public, key-free, DOI-versioned dataset on MDR:
#     - https://mdr.nims.go.jp/concern/datasets/4q77fv540  (SuperCon 2)
#         · supercon2_v22.12.03.csv  — 40,324 measured Tc records / 37,700
#           papers. Direct file download (verified live 2026-05-23, HTTP 200,
#           Content-Type text/csv):
#             https://mdr.nims.go.jp/filesets/<uuid>/download
#   Columns (verified live): id, rawMaterial, materialId, name, formula,
#   doping, shape, materialClass, fabrication, substrate, variables,
#   criticalTemperature, criticalTemperatureMeasurementMethod,
#   appliedPressure, section, subsection, hash, title, doi, authors,
#   publisher, journal, year.
#
# Behavior:
#   - Default: GET the public MDR SuperCon-2 CSV (~14 MB), stream-filter rows
#     by formula, emit typed measurement records. gate_type="external-api".
#   - Any network / decode failure → gate_type="external-api-failed", honest
#     skip, exit 0 (graceful degrade; mirrors cod/aflow d2/d7 stance).
#   - $SUPERCON_CSV_PATH set to a readable local CSV → parse it instead of
#     hitting the network (offline / pinned-vintage / behind-firewall path).
#     gate_type="install-gated" (user supplied the data file). Same row shape.
#
# d2 access-wall note: the legacy `supercon.nims.go.jp/` register-only UI is a
# wall (no key-free REST). Breakthrough path TAKEN: the MDR migration (2022)
# republished the identical corpus as a public CC-BY-4.0 file download — no
# registration, no key. We hit that. Fallbacks if MDR drifts: (a) the
# $SUPERCON_CSV_PATH install-gated local-file path, (b) the public Stanev
# 2018 / Hamidieh 2018 ML dumps derived from the same SuperCon corpus.
#
# D72: thin adapter — GET + normalize + JSON dump, no math, no kernel share.
# D80: gate_type ∈ {external-api, external-api-failed, install-gated}.
# g3:  absorbed = false 영원히 — SuperCon Tc values are *literature-extracted*
#      (digitized FROM published papers), NOT a raw demiurge instrument run.
#      They are an `external_measured_reference` (NIMS' measurement, cited),
#      NOT our measured-oracle PASS (d6). R4 invariant + MP.md §4 honest 한계.
#      absorbed NEVER promotes for a SuperCon row.
#
# License: NIMS MDR SuperCon Datasheet / SuperCon-2 — Creative Commons BY
# Attribution 4.0 International (CC-BY-4.0; verified on the MDR dataset page,
# 2026-05-23). Free use with attribution. Per-row underlying experimental
# papers (via `doi`) carry their own publisher copyright on verbatim text;
# the numeric data points are facts (not copyrightable).

from __future__ import annotations

import csv
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


# Public MDR SuperCon-2 data file (no key, no registration; CC-BY-4.0).
# fileset uuid resolved from https://mdr.nims.go.jp/concern/datasets/4q77fv540
SUPERCON_MDR_CSV_URL = (
    "https://mdr.nims.go.jp/filesets/"
    "b737b44a-b07a-4853-9378-8ba63f644e79/download"  # supercon2_v22.12.03.csv
)
SUPERCON_MDR_DATASET_URL = "https://mdr.nims.go.jp/concern/datasets/4q77fv540"
SUPERCON_LEGACY_URL = "https://supercon.nims.go.jp/"  # register-only (superseded)
ENV_CSV_PATH = "SUPERCON_CSV_PATH"
DEFAULT_TIMEOUT_S = 60.0  # ~14 MB file — generous read budget
MAX_ROWS_EMITTED = 50  # courtesy cap — don't dump 40k rows into one record


# ─── HTTP GET (stdlib only — no requests dep) ───────────────────────────


def _http_get_text(url: str, timeout_s: float) -> tuple[str | None, str | None]:
    """Return (text_body, error_string). Never raises."""
    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "hexa-lang/supercon_query (MP-P2.3)"}
        )
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            status = getattr(resp, "status", None) or resp.getcode()
            if status is None or not (200 <= int(status) < 300):
                return None, f"SuperCon/MDR HTTP non-2xx: status={status}"
            body = resp.read().decode("utf-8", errors="replace")
        return body, None
    except urllib.error.HTTPError as he:
        return None, f"SuperCon/MDR HTTPError: {he.code} {he.reason}"
    except urllib.error.URLError as ue:
        return None, f"SuperCon/MDR URLError: {ue.reason}"
    except TimeoutError as te:
        return None, f"SuperCon/MDR timeout: {te}"
    except Exception as e:  # pragma: no cover — unexpected
        return None, f"SuperCon/MDR GET error: {type(e).__name__}: {e}"


# ─── family classification (RTSC §8.2 enum — mirrors mp/oqmd/cod/aflow) ──


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


# ─── value coercion ─────────────────────────────────────────────────────


def _parse_quantity_K(s: str | None) -> float | None:
    """Extract a numeric Kelvin value from a SuperCon `criticalTemperature`
    cell like '2.8 K', '20 K', '42K' (no space), '93' (unit optional).
    Returns None on any non-numeric / empty cell. We never invent a value;
    the raw cell is always preserved in `measured_tc_raw` for fidelity."""
    if s is None:
        return None
    tok = s.strip().split()
    if not tok:
        return None
    head = tok[0].replace(",", "")
    # tolerate a glued unit suffix ('42K' / '2.8K') by stripping a trailing K.
    if head.endswith(("K", "k")):
        head = head[:-1]
    try:
        return float(head)
    except ValueError:
        return None


def _parse_quantity_GPa(s: str | None) -> float | str | None:
    """Best-effort numeric GPa from an `appliedPressure` cell. Keep the raw
    string when it isn't a bare number (units vary: GPa, kbar, ambient)."""
    if s is None:
        return None
    raw = s.strip()
    if not raw:
        return None
    tok = raw.split()
    try:
        return float(tok[0].replace(",", ""))
    except ValueError:
        return raw


def _formula_matches(cell: str | None, formula_filter: str) -> bool:
    if cell is None:
        return False
    return cell.replace(" ", "").lower() == formula_filter.replace(" ", "").lower()


# ─── CSV row normalization ──────────────────────────────────────────────


def _normalize_supercon_row(row: dict) -> dict:
    """Project a SuperCon-2 CSV row into the demiurge-consumer shape; honest
    null for missing fields. `measured_tc_K` carries NIMS' literature-
    extracted Tc — flagged `external_measured_reference` (NOT our oracle)."""
    r = {k: (v.strip() if isinstance(v, str) else v) for k, v in row.items()}
    return {
        "supercon_id": r.get("id"),
        "formula": r.get("formula"),
        "name": r.get("name") or None,
        "raw_material": r.get("rawMaterial") or None,
        "material_class": r.get("materialClass") or None,
        "doping": r.get("doping") or None,
        "variables": r.get("variables") or None,
        # NIMS' literature-extracted measured Tc — an EXTERNAL reference, not
        # a demiurge measured-oracle PASS (d6). absorbed stays false.
        "measured_tc_K": _parse_quantity_K(r.get("criticalTemperature")),
        "measured_tc_raw": r.get("criticalTemperature") or None,
        "tc_measurement_method": r.get("criticalTemperatureMeasurementMethod")
        or None,
        "applied_pressure_GPa": _parse_quantity_GPa(r.get("appliedPressure")),
        "tc_provenance": "external_measured_reference",  # NIMS, not our oracle
        "doi": r.get("doi") or None,
        "title": r.get("title") or None,
        "authors": r.get("authors") or None,
        "journal": r.get("journal") or None,
        "year": r.get("year") or None,
    }


def _scan_csv_rows(
    text: str, formula_filter: str
) -> tuple[list[dict], int, int]:
    """Stream the CSV, filter by formula, normalize. Returns
    (rows, total_scanned, filtered_out). Capped at MAX_ROWS_EMITTED."""
    rows: list[dict] = []
    total = 0
    filtered = 0
    reader = csv.DictReader(io.StringIO(text))
    for raw in reader:
        total += 1
        if not _formula_matches(raw.get("formula"), formula_filter):
            filtered += 1
            continue
        rows.append(_normalize_supercon_row(raw))
        if len(rows) >= MAX_ROWS_EMITTED:
            break
    return rows, total, filtered


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, formula: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "NIMS SuperCon Database — National Institute for Materials Science, "
        "Japan (2002~). Migrated to the Materials Data Repository (MDR) 2022. "
        "https://mdr.nims.go.jp/concern/datasets/4q77fv540 (SuperCon 2).",
        "Stanev et al. 2018, npj Comput. Mater. 4, 29 — 'Machine learning "
        "modeling of superconducting critical temperature' (downstream user "
        "of the SuperCon corpus).",
        "Hamidieh 2018, Comput. Mater. Sci. 154, 346 — 'A data-driven "
        "statistical model for predicting the critical temperature of a "
        "superconductor' (also uses SuperCon).",
        "MP.md Phase 2 §P2.3 — key-free supplementary-source ingest "
        "(experimental-Tc corpus sibling to MP/OQMD/COD/AFLOW).",
    ]

    scope_caveats = [
        "(s1) external_measured_reference, NOT our oracle — SuperCon Tc "
        "values are literature-extracted (digitized FROM published papers by "
        "NIMS), not a demiurge raw-instrument measurement run. d6: "
        "absorbed=true requires OUR MeasuredOracleRef PASS, never a cited "
        "external Tc. `measured_tc_K` is marked tc_provenance="
        "'external_measured_reference'.",
        "(s2) Tc definition varies row-to-row (onset vs midpoint vs zero) and "
        "the raw cell may carry units / ranges; we keep `measured_tc_raw` for "
        "fidelity and best-effort-parse the leading number into "
        "`measured_tc_K`. `tc_measurement_method` preserved when present.",
        "(s3) Composition strings are normalized inconsistently across the DB "
        "(spaces, doping placeholders like 'x'); downstream must reconcile "
        "against MP/OQMD/COD/AFLOW formulas before joining. We filter on an "
        "exact whitespace-stripped case-insensitive `formula` match.",
        "(s4) absorbed=false for ALL SuperCon rows — MP.md §4 honest 한계 + "
        "d6/d7. Promotion to absorbed=true requires OUR raw measurement "
        "attestation, never a literature digitization (even a measured one).",
        "(s5) row-emit capped at "
        f"{MAX_ROWS_EMITTED} (courtesy; the full file is ~40k rows). "
        "csv_stats.total_rows_scanned reports the full scan size.",
    ]

    csv_path_env = os.environ.get(ENV_CSV_PATH)
    gate_type: str
    skipped_reason: str | None = None
    csv_source: str | None = None
    rows: list[dict] = []
    total_scanned = 0
    filtered_out = 0

    if csv_path_env:
        # install-gated: user supplied a local CSV (offline / pinned vintage).
        gate_type = "install-gated"
        csv_path = Path(csv_path_env).expanduser()
        if not csv_path.exists() or not csv_path.is_file():
            skipped_reason = (
                f"${ENV_CSV_PATH}={csv_path_env!r} does not resolve to a "
                f"readable file. Honest skip — fix the path or unset to use "
                f"the public MDR download."
            )
        else:
            csv_source = str(csv_path)
            try:
                text = csv_path.read_text(encoding="utf-8", errors="replace")
                rows, total_scanned, filtered_out = _scan_csv_rows(text, formula)
            except Exception as e:
                gate_type = "external-api-failed"
                skipped_reason = (
                    f"local CSV parse failed: {type(e).__name__}: {e}"
                )
    else:
        # default: hit the public MDR SuperCon-2 file (key-free, CC-BY-4.0).
        gate_type = "external-api"
        csv_source = SUPERCON_MDR_CSV_URL
        body, err = _http_get_text(SUPERCON_MDR_CSV_URL, DEFAULT_TIMEOUT_S)
        if err is not None or body is None:
            gate_type = "external-api-failed"
            skipped_reason = err or "empty MDR SuperCon CSV body"
            csv_source = None
        else:
            try:
                rows, total_scanned, filtered_out = _scan_csv_rows(body, formula)
            except Exception as e:
                gate_type = "external-api-failed"
                skipped_reason = f"CSV parse failed: {type(e).__name__}: {e}"
                csv_source = None

    record = {
        "domain": "material",
        "verb": "query",
        "kind": "supercon_lookup",
        "stamp": stamp,
        "producer": "supercon_query@material-p2.3",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,            # external measured ref != our oracle (d6/R4)
        "gate_type": gate_type,       # external-api | external-api-failed | install-gated
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "formula": formula,
            "composition_normalized": formula.replace(" ", ""),
            "family_classification": _classify_family(formula),
            "csv_path_env_var": ENV_CSV_PATH,
            "csv_source": csv_source,
        },
        "csv_stats": {
            "total_rows_scanned": total_scanned,
            "filtered_out_by_formula": filtered_out,
            "rows_emitted": len(rows),
            "row_emit_cap": MAX_ROWS_EMITTED,
        },
        "row_count": len(rows),
        "rows": rows,
        "tc_is_external_measured_reference": True,  # NIMS measured, not our oracle
        "scope_caveats": scope_caveats,
        "citations": citations,
        "attribution": (
            "Data from the NIMS SuperCon Database via the Materials Data "
            f"Repository (MDR), {SUPERCON_MDR_DATASET_URL}. "
            "Licensed CC-BY-4.0 (attribution required). Also cite the "
            "underlying experimental paper in each row's `doi` field."
        ),
        "license": "CC-BY-4.0 (NIMS MDR SuperCon Datasheet / SuperCon-2)",
        "provenance": {
            "source_url": csv_source or SUPERCON_MDR_CSV_URL,
            "source_citation": (
                "NIMS SuperCon Database (2002~) via MDR (2022), "
                "supercon2_v22.12.03"
            ),
            "primary_refs": [
                "NIMS SuperCon DB (2002~) — primary curated experimental corpus.",
                "npj Comput. Mater. 4 29 (Stanev 2018) — ML user of SuperCon.",
                "Comput. Mater. Sci. 154 346 (Hamidieh 2018) — ML user.",
            ],
            "api_endpoints": [
                f"{SUPERCON_MDR_CSV_URL}  (public file download · no key · CC-BY-4.0)",
                f"{SUPERCON_MDR_DATASET_URL}  (MDR dataset landing page)",
                f"env: ${ENV_CSV_PATH}  (install-gated local CSV import path)",
                f"{SUPERCON_LEGACY_URL}  (legacy register-only UI · SUPERSEDED)",
            ],
        },
        "rtsc_anchor": (
            "MP.md Phase 2 §P2.3 — NIMS SuperCon (MDR public CC-BY-4.0) "
            "experimental-Tc corpus sibling to MP/OQMD/COD/AFLOW "
            "(external_measured_reference; absorbed=false 영구)"
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
        f"  · gate_type={gate_type}  rows_emitted={len(rows)}  "
        f"scanned={total_scanned}  csv_source={csv_source!r}"
    )
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    for r in rows[:5]:
        print(
            f"    - {r.get('formula')}  Tc={r.get('measured_tc_K')} K "
            f"(raw={r.get('measured_tc_raw')!r})  "
            f"P={r.get('applied_pressure_GPa')}  doi={r.get('doi')}"
        )
    if len(rows) > 5:
        print(f"    ... ({len(rows) - 5} more rows)")
    print(
        "[material+query·supercon] absorbed=false (NIMS Tc is an "
        "external_measured_reference — literature-extracted, NOT our "
        "measured-oracle; d6/d7 + MP.md §4 — SuperCon rows NEVER promote)"
    )
    return 0


if __name__ == "__main__":
    argv = sys.argv
    out_dir = argv[1] if len(argv) > 1 else "/tmp/material_query_supercon"
    formula = argv[2] if len(argv) > 2 else "MgB2"
    sys.exit(main(out_dir, formula))
