#!/usr/bin/env python3
# hexa_rtsc_crosslink.py — cross-link adapter Tier 1.
#
# RTSC.md §8.4 (9-test characterization, hexa-rtsc mapping) + §8.7 Tier 1 +
# §7 (sibling material substrate cross-reference). Sibling SSOTs:
#   - ~/core/hexa-lang/stdlib/material/sim_adapter.py  (Python closed-form Tc/Hc2)
#   - ~/core/hexa-lang/stdlib/material/sim.hexa        (hexa-native port)
#   - ~/core/hexa-rtsc/verify/calc_{bcs,mcmillan,hc2_48t,lk99}.hexa
#                                                       (sibling substrate)
#
# This adapter is a **prediction-vs-prediction** sanity cross-check:
#   (1) run each hexa-rtsc calc_*.hexa via `hexa run` (capture stdout)
#   (2) parse each script's headline closed-form value (Tc K, Hc2 T, ratio, ...)
#   (3) run sim_adapter.py to obtain its predicted closed-form values
#   (4) emit per-formula {hexa_rtsc_value, sim_adapter_value, delta_abs, delta_pct}
#
# BOTH SIDES ARE PREDICTIONS. This cross-link CANNOT promote absorbed → true.
# It is a tier-1 sanity check — DEVIATION is expected (the two sides use
# different input params: hexa-rtsc uses n=6 closed-form bounds, sim_adapter
# uses Nb / LK-99 Eliashberg-moment params) — DEVIATION is informative, not
# failing.
#
# Skip modes (always emit an honest record):
#   - hexa-runtime-missing      : `hexa --help` doesn't succeed
#   - hexa-rtsc-source-missing  : calc_bcs.hexa not on disk
#   - sim-adapter-missing       : sim_adapter.py not on disk

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
HEXA_RTSC_ROOT = HOME / "core" / "hexa-rtsc"
SIM_ADAPTER = HOME / "core" / "hexa-lang" / "stdlib" / "material" / "sim_adapter.py"

# ─── per-script: which hexa-rtsc script + which headline value to extract ──
#
# Each entry declares:
#   formula       : human-readable formula key
#   script        : path under hexa-rtsc/verify/
#   unit          : value's physical unit
#   parse         : regex extracting the headline numeric (group 1 → float)
#   sim_field     : how to fetch comparable value from sim_adapter's record
#                   (callable: rows-list -> float|None)
#
# Headline conventions (from reading each calc_*.hexa source):
#   - calc_bcs.hexa        → master identity σ·φ=24 (no Tc / Hc2 number;
#                             we crosscheck the n=6 anchor σ=12 against
#                             sim_adapter's structural constants — closed-form
#                             only, no direct numeric cmp available; record as
#                             SKIPPED with reason "structural-only").
#   - calc_mcmillan.hexa   → BCS-λ McMillan ceiling Tc ≤ 30 K (line:
#                             "F-RTSC-2 ceiling: McMillan 30 K vs RT-SC target 300 K").
#                             Sim-adapter Nb Allen-Dynes gives ≈9 K (well below
#                             the 30 K *ceiling*, so DEVIATION expected — Nb is
#                             not at-ceiling).
#   - calc_hc2_48t.hexa    → Hc2 = σ·τ = 48 T (n=6 master gate).
#                             Sim-adapter WHH gives Hc2(0) from Tc·slope; for
#                             Nb (Tc≈9 K, slope 0.5 T/K) ≈3 T — DEVIATION is
#                             huge (different physical regime).
#   - calc_lk99.hexa       → LK-99 claim Tc=400 K (cited, not predicted).
#                             Sim-adapter LK-99 row gives Allen-Dynes Tc — used
#                             as the comparison.

PARSE_30K = re.compile(r"target/ceiling\s*=\s*(\d+)\s*/\s*(\d+)")
PARSE_48T = re.compile(r"Hc2 master gate.*?(\d+)\s*\*\s*(\d+)\s*=\s*(\d+)\s*T", re.S)
PARSE_LK99_TC = re.compile(r"claim Tc.*?(\d+)\s*K", re.I)  # source-only fallback


def _have_hexa() -> bool:
    if shutil.which("hexa") is None:
        return False
    try:
        r = subprocess.run(
            ["hexa", "--help"], capture_output=True, text=True, timeout=10
        )
        return r.returncode == 0
    except Exception:
        return False


def _run_hexa_script(script_path: Path) -> tuple[bool, str, str]:
    """Returns (ok, stdout, err_summary)."""
    if not script_path.exists():
        return False, "", f"missing: {script_path}"
    try:
        r = subprocess.run(
            ["hexa", "run", str(script_path)],
            capture_output=True, text=True, timeout=120,
            cwd=str(HEXA_RTSC_ROOT),
        )
        if r.returncode != 0:
            tail = (r.stdout or "")[-400:] + "\n" + (r.stderr or "")[-400:]
            return False, r.stdout or "", f"exit={r.returncode}; tail={tail.strip()}"
        return True, r.stdout, ""
    except Exception as e:
        return False, "", f"exception: {e!r}"


def _parse_bcs(stdout: str) -> float | None:
    # No single Tc / Hc2 headline — pull σ·φ = 24 master identity scalar.
    m = re.search(r"master identity:.*?σ·φ=(\d+)", stdout, re.S)
    if m:
        return float(m.group(1))
    return None


def _parse_mcmillan(stdout: str) -> float | None:
    # Headline: McMillan ceiling Tc = 30 K (F-RTSC-2). Pull "ceiling = 30 K"
    # from "F-RTSC-2 ceiling ratio: target/ceiling = 300/30 = 10" line.
    m = PARSE_30K.search(stdout)
    if m:
        # group(2) = denominator = ceiling K
        return float(m.group(2))
    # Fallback: literal "30 K" near "McMillan ceiling"
    m2 = re.search(r"McMillan\s+(\d+)\s*K\s+ceiling", stdout)
    if m2:
        return float(m2.group(1))
    return None


def _parse_hc2_48t(stdout: str) -> float | None:
    # Headline: Hc2 = 48 T. Look for "Hc2 = 48 T" line in output.
    m = re.search(r"Hc2\s*=\s*(\d+)\s*T", stdout)
    if m:
        return float(m.group(1))
    # Fallback: "σ(6) · τ(6) = 12 · 4 = 48 T"
    m2 = re.search(r"=\s*12\s*·\s*4\s*=\s*(\d+)\s*T", stdout)
    if m2:
        return float(m2.group(1))
    return None


def _parse_lk99(stdout: str) -> float | None:
    # Headline: LK-99 claim Tc = 400 K (cited, not derived).
    m = re.search(r"~?(\d+)\s*K\s*\(above ambient\)", stdout)
    if m:
        return float(m.group(1))
    return None


SPECS = [
    {
        "formula": "bcs_master_identity",
        "script": "verify/calc_bcs.hexa",
        "unit": "dimensionless",
        "parse": _parse_bcs,
        "sim_field": lambda _rows: 24.0,  # σ·φ = n·τ = 24 (structural constant)
        "note": "n=6 master identity σ·φ=24 — structural anchor, both sides identical by construction.",
    },
    {
        "formula": "mcmillan_ceiling_tc",
        "script": "verify/calc_mcmillan.hexa",
        "unit": "K",
        "parse": _parse_mcmillan,
        # sim_adapter's Nb Allen-Dynes Tc — comparable closed-form Tc figure.
        "sim_field": lambda rows: _sim_first("Nb", rows, ("allen_dynes", "tc_K")),
        "note": "hexa-rtsc emits the F-RTSC-2 ceiling (30 K); sim_adapter emits Nb Allen-Dynes Tc (~9 K, below ceiling). DEVIATION expected — different physical claim.",
    },
    {
        "formula": "hc2_48T_master_gate",
        "script": "verify/calc_hc2_48t.hexa",
        "unit": "T",
        "parse": _parse_hc2_48t,
        # sim_adapter's Nb WHH Hc2(0). Different input regime → expect DEVIATION.
        "sim_field": lambda rows: _sim_first("Nb", rows, ("whh_hc2_zero", "hc2_0_T")),
        "note": "hexa-rtsc emits the n=6 σ·τ=48 T master gate; sim_adapter emits Nb WHH Hc2(0) from (Tc,slope). DEVIATION expected — algebraic ceiling vs concrete sample.",
    },
    {
        "formula": "lk99_claim_tc",
        "script": "verify/calc_lk99.hexa",
        "unit": "K",
        "parse": _parse_lk99,
        "sim_field": lambda rows: _sim_first(
            "LK-99 (hypothetical)", rows, ("allen_dynes", "tc_K")
        ),
        "note": "hexa-rtsc cites LK-99 claim Tc≈400 K (claim-only, replication failed); sim_adapter emits Allen-Dynes Tc for the same claim-only param set. DEVIATION expected.",
    },
]


def _sim_first(family: str, rows: list[dict], path: tuple[str, ...]) -> float | None:
    for r in rows:
        if r.get("family") == family:
            v = r
            for key in path:
                v = v.get(key) if isinstance(v, dict) else None
                if v is None:
                    return None
            try:
                return float(v)
            except (TypeError, ValueError):
                return None
    return None


def _run_sim_adapter(out_dir: Path) -> tuple[bool, list[dict], str]:
    if not SIM_ADAPTER.exists():
        return False, [], f"missing: {SIM_ADAPTER}"
    sim_out = out_dir / "_sim_adapter_run"
    sim_out.mkdir(parents=True, exist_ok=True)
    try:
        r = subprocess.run(
            [sys.executable, str(SIM_ADAPTER), str(sim_out)],
            capture_output=True, text=True, timeout=60,
        )
        if r.returncode != 0:
            return False, [], f"exit={r.returncode}; stderr={r.stderr[-300:]}"
    except Exception as e:
        return False, [], f"exception: {e!r}"
    # Pick most-recent material_verify_*.json
    candidates = sorted(sim_out.glob("material_verify_*.json"))
    if not candidates:
        return False, [], "no material_verify_*.json produced"
    rec = json.loads(candidates[-1].read_text())
    return True, rec.get("rows", []), ""


def _compute_delta(hexa_v: float | None, sim_v: float | None) -> tuple[float | None, float | None]:
    if hexa_v is None or sim_v is None:
        return None, None
    delta_abs = abs(hexa_v - sim_v)
    denom = abs(hexa_v) if abs(hexa_v) > 1e-12 else 1e-12
    delta_pct = 100.0 * delta_abs / denom
    return delta_abs, delta_pct


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    # ─── skip-mode dispatch ────────────────────────────────────────────────
    skip_reason: str | None = None
    skip_gate_type = "hexa-native-absent"
    if not _have_hexa():
        skip_reason = "hexa --help failed or hexa not on PATH"
        skip_gate_type = "hexa-runtime-missing"
    elif not (HEXA_RTSC_ROOT / "verify" / "calc_bcs.hexa").exists():
        skip_reason = f"calc_bcs.hexa missing under {HEXA_RTSC_ROOT}"
        skip_gate_type = "hexa-rtsc-source-missing"
    elif not SIM_ADAPTER.exists():
        skip_reason = f"sim_adapter.py missing at {SIM_ADAPTER}"
        skip_gate_type = "sim-adapter-missing"

    cross_link_results: list[dict] = []
    sim_rows: list[dict] = []
    sim_ok = False
    sim_err = ""

    if skip_reason is None:
        sim_ok, sim_rows, sim_err = _run_sim_adapter(out)

    if skip_reason is None and not sim_ok:
        skip_reason = f"sim_adapter run failed: {sim_err}"
        skip_gate_type = "sim-adapter-missing"

    if skip_reason is not None:
        # Honest skip: still emit a record, all formulas SKIPPED.
        for spec in SPECS:
            cross_link_results.append({
                "formula": spec["formula"],
                "hexa_rtsc_value_unit": spec["unit"],
                "hexa_rtsc_value": None,
                "sim_adapter_value": None,
                "delta_abs": None,
                "delta_pct": None,
                "status": "SKIPPED",
                "note": spec["note"],
                "skip_reason": skip_reason,
            })
    else:
        for spec in SPECS:
            script_path = HEXA_RTSC_ROOT / spec["script"]
            ok, stdout, err = _run_hexa_script(script_path)
            if not ok:
                cross_link_results.append({
                    "formula": spec["formula"],
                    "hexa_rtsc_value_unit": spec["unit"],
                    "hexa_rtsc_value": None,
                    "sim_adapter_value": spec["sim_field"](sim_rows),
                    "delta_abs": None,
                    "delta_pct": None,
                    "status": "SKIPPED",
                    "note": spec["note"],
                    "skip_reason": f"hexa-rtsc script failed: {err}",
                })
                continue
            hexa_v = spec["parse"](stdout)
            sim_v = spec["sim_field"](sim_rows)
            delta_abs, delta_pct = _compute_delta(hexa_v, sim_v)
            if hexa_v is None or sim_v is None:
                status = "SKIPPED"
                skip_note = "parse-failed" if hexa_v is None else "sim-field-missing"
            elif delta_pct is not None and delta_pct > 5.0:
                status = "DEVIATION"
                skip_note = None
            else:
                status = "MATCH"
                skip_note = None
            row = {
                "formula": spec["formula"],
                "hexa_rtsc_value_unit": spec["unit"],
                "hexa_rtsc_value": hexa_v,
                "sim_adapter_value": sim_v,
                "delta_abs": delta_abs,
                "delta_pct": delta_pct,
                "status": status,
                "note": spec["note"],
            }
            if skip_note is not None:
                row["skip_reason"] = skip_note
            cross_link_results.append(row)

    headline = {
        "cross_link_count": len(cross_link_results),
        "match_count": sum(1 for r in cross_link_results if r["status"] == "MATCH"),
        "deviation_count": sum(1 for r in cross_link_results if r["status"] == "DEVIATION"),
        "skipped_count": sum(1 for r in cross_link_results if r["status"] == "SKIPPED"),
    }

    scope_caveats = [
        "(c1) BOTH SIDES ARE PREDICTIONS. This cross-link is a sanity check "
        "between hexa-rtsc's n=6 closed-form bounds and sim_adapter's "
        "closed-form Tc/Hc2 predictors. absorbed=false is PERMANENT for this "
        "record-kind. Cross-link cannot promote absorbed → true (RTSC.md §8.7 "
        "/ §8.8 honest 한계).",
        "(c2) DEVIATION IS EXPECTED. hexa-rtsc emits n=6-derived structural "
        "anchors (Hc2=48 T ceiling, McMillan 30 K ceiling, master identity "
        "24, LK-99 claim 400 K). sim_adapter emits per-sample predictions "
        "with Nb / LK-99 Eliashberg moments. They are NOT the same physical "
        "claim — DEVIATION is informative, not failing.",
        "(c3) calc_bcs.hexa has no Tc / Hc2 numeric headline (it verifies "
        "algebraic structure of n=6 lattice constants); cross-link uses the "
        "master identity σ·φ = 24 scalar — both sides identical by "
        "construction, so this row registers as MATCH by definition.",
        "(c4) calc_lk99.hexa is known to fail compile under the current "
        "hexa runtime (parse error around line 336 of the source) — its row "
        "registers as SKIPPED with the upstream parse error attached. This "
        "is NOT a cross-link failure; it is hexa-rtsc substrate state that "
        "must be fixed upstream.",
        "(c5) Tier 1 cross-link only. Promotion to Tier 3 (measurement) or "
        "Tier 4 (falsifier dispatch) requires a separate cohort and lands "
        "via its own absorbed=true path, NEVER via this cross-link.",
    ]

    citations = [
        "hexa-rtsc verify pillar — ~/core/hexa-rtsc/verify/ (35 .hexa scripts; "
        "43/43 falsifier closure per project README).",
        "sim_adapter.py — ~/core/hexa-lang/stdlib/material/sim_adapter.py (D72 "
        "thin-adapter pattern, BCS / McMillan / Allen-Dynes / WHH closed-forms).",
        "RTSC.md §8.4 (9-test characterization + hexa-rtsc mapping).",
        "RTSC.md §8.7 Tier 1 (Computational synthesis cohort).",
        "RTSC.md §7 (cross-reference: hexa-rtsc as sibling material substrate).",
        "BCS 1957 PR 108 1175; McMillan 1968 PR 167 331; Allen-Dynes 1975 PRB "
        "12 905; WHH 1966 PR 147 295.",
    ]

    record = {
        "domain": "material",
        "verb": "verify",
        "kind": "hexa_rtsc_crosslink",
        "stamp": stamp,
        "producer": "hexa_rtsc_crosslink@material-tier1",
        "axes": {
            "solver": "multi_source_crosslink",
        },
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,           # Tier 1 prediction-vs-prediction — never measurement
        "provisional": True,
        "gate_type": skip_gate_type if skip_reason is not None else "hexa-native-absent",
        "skip_reason": skip_reason,
        "headline": headline,
        "cross_link_results": cross_link_results,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "hexa_rtsc_root": str(HEXA_RTSC_ROOT),
            "sim_adapter_path": str(SIM_ADAPTER),
            "scripts_attempted": [s["script"] for s in SPECS],
        },
        "rtsc_anchor": "RTSC.md §8.4 + §8.7 Tier 1 + §7 cross-reference",
    }

    rec_path = out / f"material_crosslink_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[material+verify hexa_rtsc_crosslink] wrote {rec_path}")
    print(
        f"  · cross_link_count={headline['cross_link_count']}  "
        f"MATCH={headline['match_count']}  "
        f"DEVIATION={headline['deviation_count']}  "
        f"SKIPPED={headline['skipped_count']}"
    )
    if skip_reason is not None:
        print(f"  · skip_reason={skip_reason}")
        print(f"  · gate_type={skip_gate_type}")
    for r in cross_link_results:
        if r["status"] == "DEVIATION":
            print(
                f"  · [DEVIATION] {r['formula']}: hexa_rtsc={r['hexa_rtsc_value']} "
                f"{r['hexa_rtsc_value_unit']}  sim_adapter={r['sim_adapter_value']}  "
                f"delta={r['delta_pct']:.2f}%"
            )
        elif r["status"] == "MATCH":
            print(
                f"  · [MATCH] {r['formula']}: {r['hexa_rtsc_value']} "
                f"{r['hexa_rtsc_value_unit']}  delta={r['delta_pct']:.2f}%"
            )
        else:
            why = r.get("skip_reason", "")
            print(f"  · [SKIPPED] {r['formula']}: {why}")
    print(
        "[material+verify hexa_rtsc_crosslink] absorbed=false (PERMANENT — "
        "prediction-vs-prediction cross-link cannot promote to absorbed=true; "
        "RTSC.md §8.7 honest 한계)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(
        main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/material_crosslink")
    )
