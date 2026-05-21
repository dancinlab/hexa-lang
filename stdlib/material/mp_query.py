#!/usr/bin/env python3
# mp_query.py — `material + query` Materials Project REST API thin adapter (D72).
#
# RTSC.md §8.7 Tier 1 sibling — structural / electronic data ingest from the
# Materials Project DFT database (Jain et al. APL Materials 1, 011002, 2013).
# Feeds Tier 1 sim_adapter (BCS/McMillan inputs) and Tier 2 synthesis_recipe
# with candidate-material baseline info: formula · spacegroup · density ·
# formation energy · band gap · is_metal · magnetization.
#
# Sibling adapter pattern — see `sim_adapter.py` (same dir) for the record
# shape; this file follows that shape with domain="material", verb="query".
#
# Source endpoints (legacy + new MP API are both routed through pymatgen's
# `pymatgen.ext.matproj.MPRester` dispatcher based on key length):
#   - https://legacy.materialsproject.org/rest/v2/   (16-char legacy key)
#   - https://api.materialsproject.org/              (32-char new key)
#
# D61: substrate SSOT under `hexa-lang/stdlib/material/`. Demiurge spawns via
#      `python3 ~/core/hexa-lang/stdlib/material/mp_query.py <out_dir> <formula> [<mp_id>]`.
# D72: 2nd material-domain consumer (after sim_adapter). Still a thin adapter
#      — no kernel promotion (no shared math with sim_adapter).
# D80: external-api gate when the call lands; install-gated / api-key-missing
#      when it doesn't.
# g3:  absorbed = false 영원히 — Materials Project values are DFT-computed,
#      NOT experimentally measured. Band gaps are systematically off by 30–50%
#      (PBE-GGA underestimation), formation energies have ±0.1 eV/atom error
#      bars, and Debye temperature / e-ph coupling are NOT in MP at all.
#      RTSC.md §8.7 honest 한계 + §8.8 stance — DFT ≠ measurement.

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path


# ─── pymatgen + MP API probe (honest skip on missing) ──────────────────


def _probe_pymatgen():
    """Return (MPRester_class, error_string).

    pymatgen's `MPRester` dispatches between legacy (16-char key) and new
    (32-char key) backends. We surface ImportError as a clean error string
    so the caller can emit an `install-gated` skip record.
    """
    try:
        from pymatgen.ext.matproj import MPRester  # noqa: F401

        return MPRester, None
    except ImportError as e:
        return None, f"pymatgen import failed: {e}"
    except Exception as e:  # pragma: no cover — unexpected import error
        return None, f"pymatgen import error: {e}"


def _resolve_api_key() -> tuple[str | None, str | None]:
    """Return (key, source_label) — prefer MP_API_KEY_NEW (new 32-char API)
    over MP_API_KEY (legacy 16-char). Returns (None, None) if neither set."""
    new = os.environ.get("MP_API_KEY_NEW")
    if new:
        return new, "MP_API_KEY_NEW (new API · api.materialsproject.org)"
    legacy = os.environ.get("MP_API_KEY")
    if legacy:
        return legacy, "MP_API_KEY (legacy · legacy.materialsproject.org)"
    return None, None


# ─── family classification (RTSC.md §8.2 enum) ─────────────────────────


def _classify_family(formula: str) -> str:
    """Map a pretty-formula string to the RTSC.md §8.2 candidate-material
    family enum. Heuristic / claim-only; not a substitute for a sourced
    materials-class label. Used to gate `absorbed=false` clearly on the
    LK-99-family claim row."""
    f = formula.replace(" ", "")
    f_lower = f.lower()
    # LK-99 / lead-apatite hypotheticals — Pb10Cu(PO4)6O and variants
    if (("pb10" in f_lower or "pb_10" in f_lower) and "p" in f_lower
            and "o" in f_lower):
        return "lk-99-family (hypothetical · NOT replicated)"
    if "mgb2" in f_lower or f_lower == "mgb_2":
        return "mgb2 (replicated 2001~)"
    # Heavy hydrides — H3S, LaH10, CaH6, ScH9, YH6 (GPa-pressure-stable only)
    if f in {"H3S", "LaH10", "CaH6", "ScH9", "YH6"}:
        return "heavy-hydride (≥GPa pressure · device-impossible)"
    # YBCO / REBCO family
    if "yba2cu3o" in f_lower or "rebco" in f_lower:
        return "hts-cuprate (REBCO · replicated 1986~)"
    # BSCCO / Bi-2212 / Bi-2223
    if "bi" in f_lower and "cu" in f_lower and "o" in f_lower:
        return "hts-cuprate (BSCCO family)"
    if "hgba2ca" in f_lower or "hg-1223" in f_lower:
        return "hts-cuprate (Hg-1223)"
    # Iron-based
    if ("fese" in f_lower or "fease" in f_lower
            or "feas" in f_lower or "bafe2as2" in f_lower):
        return "iron-based-sc (FeSC · replicated 2008~)"
    # LTS — NbTi, Nb3Sn, Nb3Ge
    if f in {"NbTi", "Nb3Sn", "Nb3Ge"}:
        return "lts (low-Tc · industry mature)"
    return "unclassified (not in RTSC §8.2 candidate matrix)"


# ─── MP query (only runs when both pymatgen + API key are present) ─────


def _query_mp(MPRester, api_key: str, formula: str,
              mp_id_filter: str | None) -> tuple[list[dict], str | None]:
    """Run the MP query. Returns (rows, error_string).

    On any network / API / version-mismatch failure, returns ([], err)
    so the caller can emit an honest skip record. NEVER raises.
    """
    rows: list[dict] = []
    try:
        with MPRester(api_key) as mpr:
            # `MPRester` dispatches new (32-char) vs legacy (≤17-char) under
            # the hood. The query surface differs between the two backends;
            # we use the broadest call that exists on both: pull a single
            # mp-id's full doc when mp_id_filter is given, otherwise query
            # by formula.
            if mp_id_filter is not None:
                # Try the new API first (mp-api) — `summary.search`
                try:
                    docs = mpr.summary.search(
                        material_ids=[mp_id_filter]
                    )
                except AttributeError:
                    # legacy MPRester — `query` method
                    docs = mpr.query(
                        criteria={"task_id": mp_id_filter},
                        properties=[
                            "material_id", "pretty_formula", "spacegroup",
                            "density", "formation_energy_per_atom",
                            "e_above_hull", "band_gap", "is_metal",
                            "total_magnetization", "theoretical",
                            "nsites", "volume",
                        ],
                    )
            else:
                try:
                    docs = mpr.summary.search(formula=formula)
                except AttributeError:
                    docs = mpr.query(
                        criteria={"pretty_formula": formula},
                        properties=[
                            "material_id", "pretty_formula", "spacegroup",
                            "density", "formation_energy_per_atom",
                            "e_above_hull", "band_gap", "is_metal",
                            "total_magnetization", "theoretical",
                            "nsites", "volume",
                        ],
                    )
            for d in docs:
                rows.append(_normalize_doc(d))
        return rows, None
    except Exception as e:
        return [], f"MP API call failed: {type(e).__name__}: {e}"


def _getattr_or_key(doc, name, default=None):
    """Dual-access helper — new-API docs expose attrs (`doc.material_id`),
    legacy returns dicts (`doc['material_id']`). Try both, fall back to
    default."""
    if isinstance(doc, dict):
        return doc.get(name, default)
    return getattr(doc, name, default)


def _normalize_doc(doc) -> dict:
    """Project an MP summary doc (new or legacy schema) into a flat row
    with the fields the demiurge consumer cares about. Missing fields →
    honest null (not silently zero)."""
    mp_id = _getattr_or_key(doc, "material_id") or _getattr_or_key(doc, "task_id")
    pretty = _getattr_or_key(doc, "formula_pretty") or _getattr_or_key(doc, "pretty_formula")
    spacegroup = _getattr_or_key(doc, "symmetry") or _getattr_or_key(doc, "spacegroup")
    sg_summary = None
    if spacegroup is not None:
        # new-API: `symmetry.symbol` / `symmetry.number`
        sym_symbol = _getattr_or_key(spacegroup, "symbol")
        sym_number = _getattr_or_key(spacegroup, "number")
        if sym_symbol is None and isinstance(spacegroup, dict):
            sym_symbol = spacegroup.get("symbol") or spacegroup.get("source")
            sym_number = spacegroup.get("number")
        sg_summary = {
            "symbol": sym_symbol,
            "number": sym_number,
        }
    nsites = _getattr_or_key(doc, "nsites")
    density = _getattr_or_key(doc, "density")
    volume = _getattr_or_key(doc, "volume")
    theoretical = _getattr_or_key(doc, "theoretical")
    # `theoretical_or_experimental` label
    if theoretical is True:
        toe = "theoretical"
    elif theoretical is False:
        toe = "experimental (ICSD-anchored)"
    else:
        toe = None
    return {
        "mp_id": mp_id,
        "formula_pretty": pretty,
        "structure_summary": {
            "spacegroup": sg_summary,
            "nsites": nsites,
            "density_g_cm3": density,
            "volume_A3": volume,
        },
        "formation_energy_per_atom_eV": _getattr_or_key(
            doc, "formation_energy_per_atom"),
        "energy_above_hull_eV": (
            _getattr_or_key(doc, "energy_above_hull")
            or _getattr_or_key(doc, "e_above_hull")
        ),
        "band_gap_eV": _getattr_or_key(doc, "band_gap"),
        "debye_temp_K": None,  # NOT in MP — honest null. Tier 1 sim_adapter
                               # ingests this from a separate source.
        "is_metal": _getattr_or_key(doc, "is_metal"),
        "total_magnetization": _getattr_or_key(doc, "total_magnetization"),
        "theoretical_or_experimental": toe,
    }


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, formula: str, mp_id_filter: str | None) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "Jain et al. 2013, APL Materials 1, 011002 — 'Commentary: The "
        "Materials Project: A materials genome approach to accelerating "
        "materials innovation' (MP DB primary citation).",
        "Ong et al. 2013, Computational Materials Science 68, 314 — "
        "'Python Materials Genomics (pymatgen): A robust, open-source "
        "Python library for materials analysis'.",
        "MP API docs — https://docs.materialsproject.org.",
        "RTSC.md §8.7 Tier 1 sibling — structural/electronic data ingest "
        "feeds sim_adapter (Tc prediction) + synthesis_recipe (Tier 2).",
    ]

    scope_caveats = [
        "(s1) Materials Project values are DFT-computed (PBE-GGA), NOT "
        "experimentally measured. Band gaps are systematically "
        "underestimated by 30-50% (DFT gap problem); formation energies "
        "have ±0.1 eV/atom error bars; lattice constants are typically "
        "+1-3% overestimated.",
        "(s2) Debye temperature and electron-phonon coupling (λ, ω_log, "
        "μ*) are NOT exposed in standard MP summary endpoints — Tier 1 "
        "sim_adapter must ingest these from a separate source (phonon "
        "DB / Allen-Dynes Table I / first-principles paper). MP rows "
        "have debye_temp_K=null by design.",
        "(s3) Tc prediction is NOT in MP. This adapter ingests "
        "*structural and electronic* data only. Tc inference requires "
        "λ + ω_log + μ* fed into McMillan/Allen-Dynes via sim_adapter, "
        "or a full Eliashberg solve (hexa-native-absent).",
        "(s4) absorbed=false for all MP-derived rows — DFT ≠ measurement. "
        "RTSC.md §8.7 honest 한계 + §8.8 g3 stance. LK-99-family rows are "
        "additionally claim-only (formula entries exist in MP as "
        "theoretical structures with no replicated Tc).",
    ]

    # Determine gate state.
    MPRester, import_err = _probe_pymatgen()
    api_key, key_source = _resolve_api_key()

    skipped_reason: str | None = None
    gate_type: str
    rows: list[dict] = []
    backend_used: str | None = None

    if MPRester is None:
        gate_type = "install-gated"
        skipped_reason = (
            f"{import_err}. Install: `pip install pymatgen` (legacy MPRester) "
            f"or `pip install mp-api` (new API). Honest skip — adapter never "
            f"installs behind the user's back."
        )
    elif api_key is None:
        gate_type = "api-key-missing"
        skipped_reason = (
            "Neither MP_API_KEY nor MP_API_KEY_NEW is set in env. Get a "
            "free key at https://materialsproject.org/api (new 32-char) or "
            "https://legacy.materialsproject.org/dashboard (legacy 16-char). "
            "Honest skip — adapter never embeds a key."
        )
    else:
        gate_type = "external-api"
        backend_used = key_source
        rows, query_err = _query_mp(
            MPRester, api_key, formula, mp_id_filter
        )
        if query_err is not None:
            # Network / version / API error — keep adapter exit 0, surface
            # as skip reason. Caller decides whether to retry.
            skipped_reason = query_err

    # Provenance: link to the first hit's MP page if any; else the formula
    # search page.
    if rows and rows[0].get("mp_id"):
        first_mp_id = rows[0]["mp_id"]
        source_url = f"https://materialsproject.org/materials/{first_mp_id}"
    else:
        source_url = (
            f"https://materialsproject.org/materials?formula={formula}"
        )

    record = {
        "domain": "material",
        "verb": "query",
        "kind": "materials_project_lookup",
        "stamp": stamp,
        "producer": "mp_query@material-tier1-sibling",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,           # DFT ≠ measurement; never absorb
        "gate_type": gate_type,      # external-api | install-gated | api-key-missing
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "formula": formula,
            "mp_id_filter": mp_id_filter,
            "family_classification": _classify_family(formula),
        },
        "backend": backend_used,
        "row_count": len(rows),
        "rows": rows,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_url": source_url,
            "source_citation": (
                "Jain et al. APL Materials 1, 011002 (2013)"
            ),
            "primary_refs": [
                "APL Materials 1 011002 (Jain 2013) — MP DB.",
                "Comput Mater Sci 68 314 (Ong 2013) — pymatgen lib.",
            ],
            "api_endpoints": [
                "https://api.materialsproject.org/  (new 32-char key)",
                "https://legacy.materialsproject.org/rest/v2/  (legacy key)",
            ],
        },
        "rtsc_anchor": (
            "RTSC.md §8.2 (family matrix) + §8.5 (handoff schema) "
            "+ §8.7 Tier 1 sibling (structural/electronic data)"
        ),
    }

    rec_path = out / f"material_query_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    # Headline
    print(f"[material+query] wrote {rec_path}")
    print(
        f"  · formula={formula!r}  mp_id_filter={mp_id_filter!r}  "
        f"family={record['query']['family_classification']!r}"
    )
    print(f"  · gate_type={gate_type}  row_count={len(rows)}")
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    else:
        for r in rows[:5]:
            print(
                f"    - {r.get('mp_id')}  {r.get('formula_pretty')}  "
                f"E_above_hull={r.get('energy_above_hull_eV')}  "
                f"band_gap={r.get('band_gap_eV')}  "
                f"is_metal={r.get('is_metal')}"
            )
        if len(rows) > 5:
            print(f"    ... ({len(rows) - 5} more rows)")
    print(
        "[material+query] absorbed=false (DFT ≠ measurement; RTSC.md "
        "§8.7 / §8.8 — MP-derived rows NEVER promote to absorbed=true)"
    )
    return 0


if __name__ == "__main__":
    argv = sys.argv
    out_dir = argv[1] if len(argv) > 1 else "/tmp/material_query"
    formula = argv[2] if len(argv) > 2 else "MgB2"
    mp_id = argv[3] if len(argv) > 3 else None
    sys.exit(main(out_dir, formula, mp_id))
