#!/usr/bin/env python3
"""IEC 61400-12 cubic-interp kernel vs Vestas V90-2.0MW empirical curve —
G41 PREDICTION-shape measured-oracle producer.

κ-71 R10 G41 (design.md D120 contract · D121 first-flip record).

Compares the hexa-native power_curve_kernel.hexa (IEC 61400-12-1 cubic
interpolation reference, P_rated 2 MW · v_cut_in 3 · v_rated 12 · v_cut_out
25 m/s) against the **manufacturer-published empirical** power curve of
the Vestas V90-2.0MW turbine. The asymmetry between the two curves is the
PREDICTION-shape signal: the IEC cubic-interp under-/over-predicts the
empirical curve in the cubic + rated-transition regions, producing real
modeling error (NOT numeric-equivalence · κ-69/70 trap avoided).

The hexa-side kernel value is computed via the Python equivalent of the
exact same formula (cross-impl parity verified in hexa-lang PR #308 on
pool:ubu-2 · kernel main() matched ground truth exactly — Python proxy
is honest).

Honest 4-layer disclosure (D119 G37 mirror):
  Layer 1 — oracle nature: manufacturer-published power curve, NOT a
            metered/SCADA timeseries. NREL Wind Toolkit (token-gated)
            is the deferred upgrade path.
  Layer 2 — shape: PREDICTION (modeling error between IEC cubic-interp
            simplification and an empirical curve · NOT numeric-
            equivalence).
  Layer 3 — scope: single turbine model (Vestas V90-2.0MW) · single
            operating regime (sea-level density assumed · no shear /
            turbulence / wake corrections).
  Layer 4 — what would elevate: real SCADA timeseries (NREL WTK +
            per-site measurements) · multi-turbine class sweep · multi-
            site wake / turbulence correction. All DEFERRED.

Emits EnergyWindVerifyRecord-shaped JSON. R4 invariant: absorbed=False
unless mean_rel_err ≤ 0.05 over the cited operating regime; this commit
records the empirically-observed gap honestly.

Usage:
  python3 iec_vs_vestas_v90_oracle.py [--out-dir DIR] [--turbine vestas_v90]

  --out-dir   destination for JSON record (default: ./exports/energy_wind/verify/<stamp>/)
  --turbine   currently only `vestas_v90` (extensible; manufacturer table embedded)

Exit codes:
  0  measurement complete (regardless of PASS/FAIL — honest record emitted)
  1  argv / IO error
"""
from __future__ import annotations
import argparse
import bisect
import json
import os
import sys
import time
from typing import Dict, List


# ── Manufacturer-published Vestas V90-2.0MW power curve (kW per m/s) ───
# Source: Vestas V90-2.0MW spec sheet · public domain numerical table.
# Bin width 0.5 m/s; values are manufacturer-stated, NOT SCADA-derived.
VESTAS_V90: Dict[float, float] = {
    3.5: 0,     4.0: 66,    4.5: 110,   5.0: 152,   5.5: 215,   6.0: 280,
    6.5: 365,   7.0: 457,   7.5: 568,   8.0: 690,   8.5: 832,   9.0: 978,
    9.5: 1135, 10.0: 1296, 10.5: 1455, 11.0: 1598, 11.5: 1710, 12.0: 1818,
    12.5: 1893, 13.0: 1935, 13.5: 1970, 14.0: 1980, 14.5: 1995, 15.0: 2000,
}
VESTAS_V_CUT_IN  = 3.5
VESTAS_V_RATED   = 15.0
VESTAS_V_CUT_OUT = 25.0
VESTAS_P_RATED   = 2000.0


def vestas_v90_curve(v: float) -> float:
    """Linear-interpolated Vestas V90-2.0MW power (kW) for wind speed v (m/s)."""
    if v < VESTAS_V_CUT_IN:  return 0.0
    if v > VESTAS_V_CUT_OUT: return 0.0
    if v >= VESTAS_V_RATED:  return VESTAS_P_RATED
    if v in VESTAS_V90:      return float(VESTAS_V90[v])
    keys = sorted(VESTAS_V90.keys())
    i = bisect.bisect_left(keys, v)
    v0, v1 = keys[i-1], keys[i]
    p0, p1 = VESTAS_V90[v0], VESTAS_V90[v1]
    return p0 + (p1 - p0) * (v - v0) / (v1 - v0)


def iec_cubic_kernel(v: float, v_cut_in: float = 3.0, v_rated: float = 12.0,
                      v_cut_out: float = 25.0, p_rated: float = 2000.0) -> float:
    """Python equivalent of hexa-lang stdlib/kernels/wind/power_curve_kernel.hexa
    (IEC 61400-12-1 cubic-interp). Cross-impl parity vs the .hexa kernel
    verified in PR #308 (pool:ubu-2 · kernel main() exact match)."""
    if v < v_cut_in:  return 0.0
    if v > v_cut_out: return 0.0
    if v >= v_rated:  return p_rated
    num = v**3 - v_cut_in**3
    den = v_rated**3 - v_cut_in**3
    if den <= 0.0:    return 0.0
    return p_rated * num / den


def measure(v_min: float = 4.0, v_max: float = 25.0, v_step: float = 0.5) -> dict:
    """Run the measurement over the [v_min, v_max] m/s grid.

    Skips bins where the empirical oracle is < 1.0 kW (cut-in transition
    region · rel_err near-zero-denominator instability). Reports mean +
    max rel_err over the valid bins. PASS criterion (D120): mean ≤ 0.05.
    """
    bins: List[dict] = []
    rel_errs: List[float] = []

    v = v_min
    while v <= v_max + 1e-9:
        v_r = round(v, 2)
        kernel_kW = iec_cubic_kernel(v_r)
        oracle_kW = vestas_v90_curve(v_r)
        entry = {"v_ms": v_r, "kernel_kW": kernel_kW, "oracle_kW": oracle_kW}
        if oracle_kW >= 1.0:
            re = abs(kernel_kW - oracle_kW) / abs(oracle_kW)
            entry["rel_err"] = re
            rel_errs.append(re)
        else:
            entry["rel_err"] = None  # skipped
        bins.append(entry)
        v += v_step

    n = len(rel_errs)
    mean_re = sum(rel_errs) / n if n else 0.0
    max_re  = max(rel_errs) if rel_errs else 0.0
    pass_threshold = 0.05
    passed = (mean_re <= pass_threshold)

    return {
        "bins": bins,
        "n_valid_bins": n,
        "mean_rel_err": mean_re,
        "max_rel_err": max_re,
        "pass_threshold": pass_threshold,
        "passed": passed,
    }


def emit_record(out_dir: str, m: dict) -> str:
    """Emit EnergyWindVerifyRecord-shaped JSON (cockpit Codable matches).
    R4 invariant: absorbed=False unless m['passed'] (honest 2026-05-22).
    """
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    os.makedirs(out_dir, exist_ok=True)
    record = {
        "domain":   "energy_wind",
        "verb":     "verify",
        "kind":     "energy_wind_verify",
        "stamp":    stamp,
        "producer": "stdlib/energy/iec_vs_vestas_v90_oracle.py@v0.1.0",
        "measurement_gate": "GATE_OPEN" if not m["passed"] else "GATE_CLOSED_MEASURED",
        "absorbed": bool(m["passed"]),
        "scope_caveats": [
            "Manufacturer-published Vestas V90-2.0MW power curve · NOT a metered/SCADA timeseries (NREL Wind Toolkit token-gated · deferred upgrade)",
            "PREDICTION-shape · IEC cubic-interp vs empirical curve · genuine modeling error (numeric-equivalence avoided)",
            "Single turbine model (Vestas V90-2.0MW) · sea-level density · no shear / turbulence / wake corrections",
            "Real SCADA timeseries + multi-turbine sweep + wake/turbulence correction DEFERRED (4-layer disclosure floor)",
        ],
        "citations": [
            "IEC 61400-12-1 power performance measurement methodology",
            "Vestas V90-2.0MW manufacturer spec sheet (public power curve table)",
            "hexa-lang PR #308 (power_curve_kernel.hexa cross-impl parity)",
            "design.md D120 (G40 cell pick · 5-fold lock-in) · D121 (G41 first-flip honest gap)",
        ],
        "skipped_reason": None,
        "kernel_reuse": "stdlib/kernels/wind/power_curve_kernel.hexa::power_curve",
        "hexa_native_parity": {
            "kernel_path": "stdlib/kernels/wind/power_curve_kernel.hexa",
            "kernel_version": "0.1.0",
            "verified_at": "hexa-lang PR #308 merge commit (cross-impl parity vs Python ref · pool:ubu-2 · exact match)",
        },
        "measured_oracle": {
            "oracle_kind": "manufacturer_empirical_power_curve",
            "oracle_id": "vestas_v90_2_0MW",
            "n_bins": m["n_valid_bins"],
            "operating_regime_ms": [4.0, 25.0],
            "v_step_ms": 0.5,
            "mean_rel_err": m["mean_rel_err"],
            "max_rel_err": m["max_rel_err"],
            "pass_threshold": m["pass_threshold"],
            "is_measured_oracle_PASS": bool(m["passed"]),
        },
        "bins": m["bins"],
    }
    path = os.path.join(out_dir, f"energy_wind_verify_{stamp}.json")
    with open(path, "w") as f:
        json.dump(record, f, indent=2)
    return path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out-dir", default=None)
    ap.add_argument("--turbine", default="vestas_v90", choices=["vestas_v90"])
    args = ap.parse_args()

    if args.out_dir is None:
        stamp_short = time.strftime("%Y-%m-%dT%H-%M-%SZ", time.gmtime())
        args.out_dir = f"./exports/energy_wind/verify/{stamp_short}"

    m = measure()
    path = emit_record(args.out_dir, m)

    print(f"[wind] turbine={args.turbine}  n_bins={m['n_valid_bins']}")
    print(f"[wind] mean_rel_err={m['mean_rel_err']:.6f}  max_rel_err={m['max_rel_err']:.6f}")
    print(f"[wind] PASS<=0.05: {'YES' if m['passed'] else 'NO (honest gap · absorbed stays false · R4 invariant respected)'}")
    print(f"[wind] record: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
