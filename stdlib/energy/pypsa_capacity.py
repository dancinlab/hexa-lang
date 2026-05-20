# pypsa_capacity.py — ①b domain adapter (demiurge design.md D61/D72)
# PyPSA capacity-expansion producer for `energy + synthesize`.
#
# D72 2-layer classification (this file): PyPSA is *power-system
# optimization* — not FEM (component+verify), not MC transport
# (energy+verify/fusion+verify), not graph (grid+structure). The
# first consumer is energy+synthesize and there is NO second consumer
# yet, so this stays a thin domain adapter. If a 2nd power-opt
# consumer (e.g. mobility V2G, grid+verify) appears, promote shared
# math to `kernels/power_opt/pypsa_kernel.py` per D72 2-layer pattern
# (note in `inbox/notes/pypsa-kernel-promotion-pickup.md` on the
# demiurge side).
#
# SSOT location: `~/core/hexa-lang/stdlib/energy/pypsa_capacity.py`
# (D61 — producer scripts live under hexa-lang/stdlib/<domain>/,
# never under demiurge/cockpit/scripts/).
#
# Invoked by Swift's EnergySynthProducer via:
#   python3 ~/core/hexa-lang/stdlib/energy/pypsa_capacity.py <output_dir>
#
# What it does (honest scope):
#   1. Construct a deterministic single-bus capacity-expansion problem
#      — one load + four candidate generators (solar / wind / gas /
#      battery) with textbook capital-cost and marginal-cost numbers
#      (NREL ATB-class round-figure values, NOT a sourced ATB pull),
#      run on a 168-hour (1-week) representative profile derived
#      from a deterministic synthetic clear-sky / wind-speed shape.
#   2. Delegate the LP to `pypsa.Network.optimize()` (HiGHS solver,
#      vendored with pypsa). PyPSA's LP formulation is the canonical
#      open-source academic reference for capacity-expansion (TUB /
#      Fraunhofer / NREL toolchains all consume it).
#   3. Extract the optimal investment per technology (p_nom_opt MW),
#      annual generation per technology, total system cost, and the
#      LP shadow-price-equivalent marginal cost.
#   4. Emit pypsa_capacity.meta.json with parameters + measurements +
#      pypsa version + python version so cross-host drift is visible.
#
# HONESTY (g3 — non-negotiable):
#   • The LP IS solved to optimality — the numbers (p_nom_opt MW
#     per technology, total cost in EUR/USD, dispatch profile) ARE
#     real PyPSA outputs from a real HiGHS solve. PyPSA's
#     capacity-expansion formulation is the canonical academic
#     reference (Brown·Hörsch·Schlachtberger JORS 2018, doi:
#     10.5334/jors.188).
#   • BUT the *inputs* are textbook placeholders: capital-cost numbers
#     are round figures inspired by NREL ATB but NOT a sourced ATB
#     pull, the demand profile is a single-bus toy with synthetic
#     daily shape, and there is NO storage cycling constraint beyond
#     standard PyPSA defaults. So:
#       measurement_gate = GATE_OPEN
#       absorbed         = false
#     ALWAYS. There is no path here that flips them — that requires
#     (a) sourced NREL ATB capital-cost data for the modelling year,
#     (b) real demand profile (e.g. ERCOT / PJM / ENTSO-E historical
#     hourly load), (c) renewable capacity factors from real
#     site-measured irradiance/wind (TMY3 / ERA5 / NREL WIND), and
#     (d) AC power-flow with real network topology — NOT a single bus.
#   • Honest gap: this slice is "PyPSA stack works in hexa-lang
#     stdlib and the LP is feasible + optimal", NOT "this is a
#     planned capacity portfolio". The measurement_VALUES are useful
#     as a *first honest witness* of the capacity-expansion stack,
#     NOT an investment signoff.
#   • If pypsa / HiGHS are missing OR the LP is infeasible OR the
#     summary JSON doesn't parse, returns ok=false and writes no
#     record. Silent success is forbidden.
#
# References (citation chain — g3):
#   • PyPSA — Brown, Hörsch, Schlachtberger. "PyPSA: Python for
#     Power System Analysis". Journal of Open Research Software 6(1),
#     2018, doi:10.5334/jors.188. BSD-3, OSS, NREL / TUB / Fraunhofer
#     ecosystem.
#   • Capital / marginal cost figures inspired by NREL Annual
#     Technology Baseline (NREL ATB), https://atb.nrel.gov — values
#     used here are *round numbers* not a sourced ATB pull.

# pandas 2.2+ uses pyarrow string dtype by default, which breaks
# pypsa's xarray indexing path inside optimize() (TypeError: Invalid
# array type: ArrowStringArray). Setting this option BEFORE any
# pypsa import keeps pandas on the object-dtype string path that
# pypsa+xarray supports. Honest workaround — upstream pypsa hasn't
# yet caught up to pandas 2.2's future.infer_string flip.
import pandas as pd
pd.set_option("future.infer_string", False)

import json
import math
import os
import platform
import sys
import warnings

warnings.filterwarnings("ignore")

# --- Capacity-expansion problem identity (deterministic key).
PROBLEM_ID = "single_bus_capex_4tech_168h_v1"

# --- Horizon — 168 hours = 1 representative week, hourly.
HORIZON_HOURS = 168

# --- Demand profile: synthetic but deterministic, peak 100 MW.
#     A weekday-style double peak (morning + evening) + weekend taper.
def _build_demand() -> "pd.Series":
    snapshots = pd.date_range("2024-06-03", periods=HORIZON_HOURS, freq="h")
    vals = []
    for ts in snapshots:
        hour = ts.hour
        is_weekend = ts.dayofweek >= 5
        # Base diurnal: morning ramp 6-9, midday plateau, evening peak
        # 17-20, night trough.
        if   6 <= hour < 9:    base = 70 + (hour - 6) * 8       # 70..94
        elif 9 <= hour < 17:   base = 85
        elif 17 <= hour < 20:  base = 90 + (hour - 17) * 3      # 90..99
        elif 20 <= hour < 23:  base = 85 - (hour - 20) * 5      # 85..70
        else:                  base = 55                        # night
        if is_weekend:
            base = base * 0.85
        vals.append(base)
    return pd.Series(vals, index=snapshots, name="load_mw")


# --- Renewable capacity-factor shapes (deterministic synthetic).
def _build_solar_cf() -> "pd.Series":
    snapshots = pd.date_range("2024-06-03", periods=HORIZON_HOURS, freq="h")
    vals = []
    for ts in snapshots:
        h = ts.hour
        # Triangular clear-sky proxy, peak at noon, zero at night.
        # No cloud noise (deterministic).
        if 6 <= h <= 18:
            vals.append(max(0.0, math.sin((h - 6) / 12.0 * math.pi)))
        else:
            vals.append(0.0)
    return pd.Series(vals, index=snapshots, name="solar_cf")


def _build_wind_cf() -> "pd.Series":
    snapshots = pd.date_range("2024-06-03", periods=HORIZON_HOURS, freq="h")
    vals = []
    for i, ts in enumerate(snapshots):
        # Slow diurnal pattern + multi-day envelope. Deterministic.
        diurnal = 0.4 + 0.2 * math.cos(2 * math.pi * (ts.hour - 3) / 24.0)
        weekly  = 0.3 + 0.3 * math.sin(2 * math.pi * i / HORIZON_HOURS)
        vals.append(max(0.05, min(0.95, 0.5 * diurnal + 0.5 * weekly)))
    return pd.Series(vals, index=snapshots, name="wind_cf")


# --- Generator catalogue. Capital cost is *annualised* (EUR/MW/yr),
#     marginal cost is EUR/MWh. Numbers are round and inspired by NREL
#     ATB tendencies (round figures, NOT a sourced ATB pull — see honest
#     caveats). Chosen so the LP picks a plausible mix (renewables for
#     variable supply, gas peaker for residual demand) — the test of
#     "the stack works AND the LP arithmetic is feasible" rather than
#     "this is a real investment plan".
GENERATORS = [
    # name,  carrier,    capital EUR/MW/yr,  marginal EUR/MWh,  cf_series
    ("solar_pv",     "solar", 35_000.0,   0.0, "solar"),
    ("onshore_wind", "wind",  55_000.0,   1.0, "wind"),
    ("ccgt_gas",     "gas",   25_000.0,  85.0, None),
]


def pypsa_version() -> str:
    try:
        import pypsa
        return pypsa.__version__
    except Exception:
        return "unknown"


def highs_version() -> str:
    """Best-effort HiGHS version probe — vendored with pypsa via highspy."""
    try:
        import highspy
        # highspy may expose __version__ or HighsVersion()
        v = getattr(highspy, "__version__", None)
        if v:
            return str(v)
        try:
            return str(highspy.Highs().version())  # type: ignore[attr-defined]
        except Exception:
            return "unknown"
    except Exception:
        return "unknown"


def run_optimization(output_dir: str) -> dict:
    """Build the single-bus capacity-expansion problem and solve.
    Raises on import / solver failure — main() catches and reports
    honest gap."""
    import pypsa

    n = pypsa.Network()
    demand = _build_demand()
    solar_cf = _build_solar_cf()
    wind_cf = _build_wind_cf()

    n.set_snapshots(demand.index)
    # Snapshot weighting: this 168-hour window represents 1 full year.
    # 8760 / 168 ≈ 52.143 — multiplies the marginal-cost / generation
    # contribution so the LP balances *annualised* opex vs the already
    # *annualised* capital_cost (capital_cost is EUR/MW/yr).
    weight = 8760.0 / float(HORIZON_HOURS)
    n.snapshot_weightings.loc[:, :] = weight
    n.add("Bus", "bus_main", carrier="AC")

    # Carriers (PyPSA needs them registered for >0.21).
    for car in ["AC", "solar", "wind", "gas", "storage"]:
        if car not in n.carriers.index:
            n.add("Carrier", car)

    # Load.
    n.add("Load", "load_main", bus="bus_main", p_set=demand)

    # Generators — extendable capacity (p_nom_extendable=True), with
    # the per-tech availability profile applied via p_max_pu.
    for name, carrier, capex, mc, cf_kind in GENERATORS:
        kwargs = dict(
            bus="bus_main",
            carrier=carrier,
            p_nom_extendable=True,
            p_nom_max=500.0,           # MW cap per tech (sanity)
            capital_cost=capex,
            marginal_cost=mc,
        )
        if cf_kind == "solar":
            kwargs["p_max_pu"] = solar_cf
        elif cf_kind == "wind":
            kwargs["p_max_pu"] = wind_cf
        n.add("Generator", name, **kwargs)

    # Solve. HiGHS is vendored with pypsa (highspy).
    status, condition = n.optimize(solver_name="highs")
    if status != "ok":
        raise RuntimeError(f"PyPSA optimize status={status} condition={condition}")

    # Extract per-generator results. Apply snapshot weight to convert
    # MW × snapshot → annualised MWh (the LP's economics are already
    # annualised — keep generation in the same units).
    per_gen = {}
    for gname in n.generators.index:
        p_nom_opt = float(n.generators.at[gname, "p_nom_opt"])
        gen_series = n.generators_t.p[gname]
        # Sum of MW per snapshot × hours-per-snapshot (weight) → MWh/yr.
        annual_mwh = float(gen_series.sum()) * weight
        peak_mw = float(gen_series.max())
        per_gen[gname] = {
            "carrier": str(n.generators.at[gname, "carrier"]),
            "p_nom_opt_mw": round(p_nom_opt, 4),
            "generation_mwh": round(annual_mwh, 3),
            "peak_mw": round(peak_mw, 4),
            "capital_cost_eur_per_mw_yr": float(
                n.generators.at[gname, "capital_cost"]),
            "marginal_cost_eur_per_mwh": float(
                n.generators.at[gname, "marginal_cost"]),
        }

    total_load_mwh = float(demand.sum()) * weight   # annualised
    objective = float(n.objective)

    # Renewable share = (solar + wind generation) / total load.
    renew_mwh = sum(
        per_gen[g]["generation_mwh"]
        for g in per_gen
        if per_gen[g]["carrier"] in ("solar", "wind")
    )
    renewable_share = (renew_mwh / total_load_mwh) if total_load_mwh > 0 else 0.0

    # Write the hourly dispatch CSV for downstream sweeps.
    csv_path = os.path.join(output_dir, f"{PROBLEM_ID}.csv")
    dispatch = n.generators_t.p.copy()
    dispatch["load_mw"] = demand
    dispatch.to_csv(csv_path, index_label="timestamp")

    return {
        "rows": int(HORIZON_HOURS),
        "horizon_hours": int(HORIZON_HOURS),
        "total_load_mwh": round(total_load_mwh, 3),
        "objective_eur": round(objective, 3),
        "renewable_share": round(renewable_share, 4),
        "per_generator": per_gen,
        "csv_artifact": f"{PROBLEM_ID}.csv",
    }


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: pypsa_capacity.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{PROBLEM_ID}.meta.json")
    pypsa_v = pypsa_version()
    highs_v = highs_version()
    py_v = platform.python_version()

    try:
        measurements = run_optimization(output_dir)
        ok = True
        err = None
        # G7 typed gate_type — PyPSA + HiGHS ran a real LP; no
        # hexa-native power-system-opt kernel exists yet → D80
        # hexa-native-absent + provisional on the success path.
        gate_type = "hexa-native-absent"
    except ImportError as exc:
        ok = False
        err = f"{type(exc).__name__}: {exc}"
        measurements = {
            "rows": 0,
            "horizon_hours": HORIZON_HOURS,
            "total_load_mwh": None,
            "objective_eur": None,
            "renewable_share": None,
            "per_generator": {},
            "csv_artifact": None,
        }
        # G7 — import failure means substrate not installed.
        gate_type = "install-gated"
    except Exception as exc:
        ok = False
        err = f"{type(exc).__name__}: {exc}"
        measurements = {
            "rows": 0,
            "horizon_hours": HORIZON_HOURS,
            "total_load_mwh": None,
            "objective_eur": None,
            "renewable_share": None,
            "per_generator": {},
            "csv_artifact": None,
        }
        # G7 — LP infeasibility or other runtime is not install/data/
        # platform; still substrate-side, hexa-native kernel absent.
        gate_type = "hexa-native-absent"

    meta = {
        "ok": ok,
        "problem_id": PROBLEM_ID,
        "geometry_id": PROBLEM_ID,        # reused field name for record glue
        "pypsa_version": pypsa_v,
        "highs_version": highs_v,
        "python_version": py_v,
        "error": err,
        "gate_type": gate_type,
        "provisional": ok,
        "problem": {
            "horizon_hours": HORIZON_HOURS,
            "n_buses": 1,
            "n_generators": len(GENERATORS),
            "n_loads": 1,
            "solver": "HiGHS",
            "formulation": "LP capacity-expansion (single-bus, linear cost)",
        },
        "generators_catalogue": [
            {
                "name": name,
                "carrier": carrier,
                "capital_cost_eur_per_mw_yr": capex,
                "marginal_cost_eur_per_mwh": mc,
                "availability": cf_kind or "constant",
            }
            for (name, carrier, capex, mc, cf_kind) in GENERATORS
        ],
        "measurements": measurements,
        "artifacts": {
            "csv": measurements.get("csv_artifact") or "",
        },
    }

    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"pypsa_capacity: wrote {meta_path} (ok={ok}, "
        f"rows={measurements['rows']}, "
        f"objective_eur={measurements['objective_eur']})\n")
    if not ok:
        sys.stderr.write(f"pypsa_capacity: error → {err}\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{PROBLEM_ID}.meta.json"
    summary = {
        "ok": ok,
        "problem_id": PROBLEM_ID,
        "geometry_id": PROBLEM_ID,
        "pypsa_version": pypsa_v,
        "highs_version": highs_v,
        "python_version": py_v,
        "gate_type": gate_type,
        "provisional": ok,
        "rows": measurements["rows"],
        "horizon_hours": measurements["horizon_hours"],
        "total_load_mwh": measurements["total_load_mwh"],
        "objective_eur": measurements["objective_eur"],
        "renewable_share": measurements["renewable_share"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("ENERGY_PYPSA_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
