# openmdao_mission.py — OpenMDAO substrate for `space + synthesize`
# (demiurge cohort producer; ROI rank 8 ⭐⭐⭐⭐ per
# inbox/notes/absorption-empty-cells-research-2026-05-20.md §3 space block).
#
# Invoked by Swift's `SpaceSynthProducer` via:
#   /opt/homebrew/bin/python3 openmdao_mission.py <output_dir>
#
# Citation: NASA GSC-17177-1 (OpenMDAO open-source SSOT, BSD-3,
# https://openmdao.org).
#
# What it does (honest scope — g3):
#   1. Builds a tiny OpenMDAO `Problem` that models a "circular-orbit
#      insertion" trade — small ΔV vs deliverable payload mass — using
#      the rocket equation (Tsiolkovsky) as the analytic ExecComp.
#   2. Sweeps the design variable `delta_v_mps` ∈ [10, 4000] m/s with
#      ScipyOptimizeDriver (SLSQP), maximising payload_mass_kg subject
#      to a propellant-mass-fraction constraint that mirrors a generic
#      upper-stage envelope (ΔV mapped to required propellant via the
#      rocket equation, capped by a propellant budget).
#   3. Repeats the optimiser sweep across N input m_initial samples
#      (3 plausible upper-stage wet masses bundled inline so the
#      producer is deterministic across hosts — no live launch data).
#   4. Writes a per-sample NDJSON trade table + a meta.json with the
#      MDO output for each sample (optimised ΔV, payload, propellant,
#      iteration count, solver status), plus openmdao + scipy versions.
#
# HONESTY (g3 — non-negotiable):
#   • OpenMDAO ScipyOptimizeDriver IS a real MDO solver — the numbers
#     ARE real optimiser output, not random. But:
#     - rocket-equation model is a TEXTBOOK analytic (1-disc., no
#       gravity loss, no atmospheric drag, no staging — a "scoping-
#       level" model not a flight-validated mission profile).
#     - input upper-stage parameters (Isp = 320 s, m_dry = 1500 kg,
#       max propellant budget) are nominal "generic upper-stage"
#       textbook values, NOT a real vehicle's measured spec sheet.
#     - the trade does NOT include AOCS/thermal/comms — single-
#       discipline ΔV-vs-payload only.
#   • absorbed = false ALWAYS — OpenMDAO is an EXTERNAL Python library
#     (pip install), NOT absorbed into hexa-lang. Same banned-absorbed
#     stance as Skyfield (space+analyze), POPPY (scope+analyze),
#     ngspice (sscb+analyze).
#   • measurement_gate stays GATE_OPEN永구 — the optimiser converges
#     for a TOY model. Stage-up to GATE_CLOSED_MEASURED would require
#     (a) a flight-validated mission profile (GMAT coupling — separate
#     ROI-15 cell, binary download, deliberately skipped this round),
#     (b) multi-discipline coupling (AOCS, thermal), (c) honest
#     ascertaining inputs (real upper-stage spec sheet or wind-tunnel
#     data).
#
# Algorithm reference: Tsiolkovsky rocket equation,
#   m_propellant = m_initial · (1 - exp(-ΔV / (Isp · g0)))
# OpenMDAO upstream:
#   https://openmdao.org · BSD-3 · NASA GSC-17177-1 (Glenn Research Center
#   technology release).

import hashlib
import json
import os
import sys
from datetime import datetime, timezone


# --- Mission model constants (textbook upper-stage, generic — g3) ---
G0_MPS2 = 9.80665             # standard gravity (exact, by definition)
ISP_S = 320.0                 # specific impulse, generic LH2/LOX upper stage
M_DRY_KG = 1500.0             # dry mass of stage (structure + payload bus)
PROPELLANT_BUDGET_KG = 12000.0   # max propellant the stage can carry

# Bundled wet-mass samples — three plausible upper-stage initial masses.
# Inline so the producer is deterministic cross-host (NO live vehicle
# database fetch — that would break the typed-record contract).
WET_MASS_SAMPLES_KG = [
    8000.0,    # small upper stage
    12500.0,   # medium
    18000.0,   # large
]

# --- Design-variable bounds for ΔV sweep ---
DV_MIN_MPS = 10.0
DV_MAX_MPS = 4000.0
DV_INITIAL_GUESS_MPS = 1500.0    # mid-range starting point


def openmdao_versions() -> dict:
    """Pin substrate versions for provenance — g3."""
    out = {}
    try:
        import openmdao
        out["openmdao"] = getattr(openmdao, "__version__", "unknown")
    except Exception:
        out["openmdao"] = "unknown"
    try:
        import scipy
        out["scipy"] = getattr(scipy, "__version__", "unknown")
    except Exception:
        out["scipy"] = "unknown"
    try:
        import numpy
        out["numpy"] = getattr(numpy, "__version__", "unknown")
    except Exception:
        out["numpy"] = "unknown"
    return out


def model_input_hash(samples: list, isp_s: float, m_dry_kg: float,
                     propellant_budget_kg: float) -> str:
    """SHA-256 of the model inputs — pins what was optimised over."""
    blob = json.dumps({
        "samples": samples,
        "isp_s": isp_s,
        "m_dry_kg": m_dry_kg,
        "propellant_budget_kg": propellant_budget_kg,
        "g0": G0_MPS2,
        "dv_bounds_mps": [DV_MIN_MPS, DV_MAX_MPS],
    }, sort_keys=True).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()[:16]


def run_mdo_for_sample(m_initial_kg: float) -> dict:
    """Build a fresh OpenMDAO Problem for ONE wet-mass sample, run the
    ScipyOptimizeDriver, return the converged trade values + solver
    diagnostics. We rebuild per-sample so each optimiser run starts
    from a clean state (no cross-sample pollution).
    """
    import openmdao.api as om

    prob = om.Problem()
    model = prob.model

    # ExecComp = analytic rocket-equation rollup.
    #   m_prop  = m_initial * (1 - exp(-dv / (isp * g0)))
    #   m_payload = m_initial - m_prop - m_dry
    # Driver maximises m_payload (i.e. minimises -m_payload), subject to
    #   m_prop ≤ propellant_budget (hard physical constraint of the stage),
    #   m_payload ≥ 0 (cannot deliver negative payload).
    import numpy as np  # local import — openmdao always brings numpy

    model.add_subsystem(
        "trade",
        om.ExecComp(
            "m_prop = m_initial * (1.0 - exp(-dv / (isp * g0)))",
            m_prop={"units": "kg"},
            m_initial={"val": m_initial_kg, "units": "kg"},
            dv={"val": DV_INITIAL_GUESS_MPS, "units": "m/s"},
            isp={"val": ISP_S, "units": "s"},
            g0={"val": G0_MPS2, "units": "m/s**2"},
        ),
        promotes=["*"],
    )
    model.add_subsystem(
        "payload",
        om.ExecComp(
            "m_payload = m_initial - m_prop - m_dry",
            m_payload={"units": "kg"},
            m_initial={"val": m_initial_kg, "units": "kg"},
            m_prop={"units": "kg"},
            m_dry={"val": M_DRY_KG, "units": "kg"},
        ),
        promotes=["*"],
    )

    # Design variable + objective (maximise payload → minimise -payload).
    # Plus a "fake" objective for OpenMDAO (it minimises) — we add an
    # ExecComp that returns -m_payload.
    model.add_subsystem(
        "obj",
        om.ExecComp(
            "neg_m_payload = -m_payload",
            m_payload={"units": "kg"},
            neg_m_payload={"units": "kg"},
        ),
        promotes=["*"],
    )

    model.add_design_var("dv", lower=DV_MIN_MPS, upper=DV_MAX_MPS)
    model.add_objective("neg_m_payload")
    model.add_constraint("m_prop", upper=PROPELLANT_BUDGET_KG)
    model.add_constraint("m_payload", lower=0.0)

    prob.driver = om.ScipyOptimizeDriver()
    prob.driver.options["optimizer"] = "SLSQP"
    prob.driver.options["maxiter"] = 200
    prob.driver.options["tol"] = 1.0e-8
    prob.driver.options["disp"] = False

    prob.setup()
    prob.set_val("dv", DV_INITIAL_GUESS_MPS)

    # `run_driver()` returns True on FAILURE (per OpenMDAO docs); we
    # invert here so `solver_ok` follows the natural reading.
    fail = prob.run_driver()
    solver_ok = not fail

    dv_opt = float(prob.get_val("dv")[0])
    m_prop_opt = float(prob.get_val("m_prop")[0])
    m_payload_opt = float(prob.get_val("m_payload")[0])

    # ΔV is "small" if the optimiser stayed below the propellant cap
    # and delivered positive payload — that is the trade-favourable
    # region. ΔV is "large" if propellant constraint is active.
    propellant_active = (m_prop_opt + 1.0e-3 >= PROPELLANT_BUDGET_KG)

    return {
        "m_initial_kg": round(m_initial_kg, 3),
        "isp_s": ISP_S,
        "m_dry_kg": M_DRY_KG,
        "propellant_budget_kg": PROPELLANT_BUDGET_KG,
        "optimised": {
            "dv_mps": round(dv_opt, 4),
            "m_propellant_kg": round(m_prop_opt, 4),
            "m_payload_kg": round(m_payload_opt, 4),
        },
        "solver": {
            "ok": bool(solver_ok),
            "optimizer": "SLSQP",
            "tol": 1.0e-8,
            "maxiter": 200,
            "propellant_constraint_active": bool(propellant_active),
        },
    }


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: openmdao_mission.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, "space_synthesize.meta.json")
    trade_path = os.path.join(output_dir, "space_synthesize_trade.ndjson")
    versions = openmdao_versions()
    input_hash = model_input_hash(
        WET_MASS_SAMPLES_KG, ISP_S, M_DRY_KG, PROPELLANT_BUDGET_KG)

    try:
        import openmdao.api  # noqa: F401 — import-time sanity
    except Exception as exc:
        sys.stderr.write(
            f"openmdao_mission: openmdao import failed — {exc}\n")
        summary = {"ok": False, "error": f"openmdao_import: {exc}",
                   "input_sha256_16": input_hash}
        sys.stderr.write(
            "OPENMDAO_MISSION_RESULT "
            + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    run_now = datetime.now(timezone.utc)
    per_sample = []
    overall_ok = True

    with open(trade_path, "w", encoding="utf-8") as trade_f:
        for wet_mass_kg in WET_MASS_SAMPLES_KG:
            try:
                rec = run_mdo_for_sample(wet_mass_kg)
            except Exception as exc:
                sys.stderr.write(
                    f"openmdao_mission: sample {wet_mass_kg} kg failed — {exc}\n")
                overall_ok = False
                rec = {
                    "m_initial_kg": round(wet_mass_kg, 3),
                    "error": str(exc),
                }
            if not rec.get("solver", {}).get("ok", False):
                overall_ok = False
            trade_f.write(json.dumps(rec, sort_keys=True) + "\n")
            per_sample.append(rec)

    # Best payload over the sweep (the "headline trade point").
    best = None
    for rec in per_sample:
        opt = rec.get("optimised") or {}
        if "m_payload_kg" not in opt:
            continue
        if best is None or opt["m_payload_kg"] > best.get("m_payload_kg", -1e18):
            best = {
                "m_initial_kg": rec["m_initial_kg"],
                "dv_mps": opt["dv_mps"],
                "m_payload_kg": opt["m_payload_kg"],
                "m_propellant_kg": opt["m_propellant_kg"],
            }

    meta = {
        "ok": overall_ok and best is not None,
        "interface": "demiurge:space:synthesize-record",
        "geometry_id": "space_circular_insertion_v1",
        "input_sha256_16": input_hash,
        "openmdao_version": versions["openmdao"],
        "scipy_version": versions["scipy"],
        "numpy_version": versions["numpy"],
        "model": {
            "name": "circular_orbit_insertion_rocket_equation",
            "discipline_count": 1,
            "design_variables": ["dv_mps"],
            "objective": "maximise(m_payload_kg)",
            "constraints": [
                "m_propellant_kg <= propellant_budget_kg",
                "m_payload_kg >= 0",
            ],
            "isp_s": ISP_S,
            "m_dry_kg": M_DRY_KG,
            "propellant_budget_kg": PROPELLANT_BUDGET_KG,
            "dv_bounds_mps": [DV_MIN_MPS, DV_MAX_MPS],
            "wet_mass_samples_kg": WET_MASS_SAMPLES_KG,
        },
        "samples": per_sample,
        "best": best,
        "run_at_utc": run_now.isoformat().replace("+00:00", "Z"),
        "artifacts": {
            "meta": os.path.basename(meta_path),
            "trade_ndjson": os.path.basename(trade_path),
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"openmdao_mission: wrote {meta_path} (ok={meta['ok']}, "
        f"samples={len(per_sample)}, best_payload="
        f"{best['m_payload_kg'] if best else 'N/A'} kg)\n")

    summary = {
        "ok": meta["ok"],
        "geometry_id": "space_circular_insertion_v1",
        "input_sha256_16": input_hash,
        "openmdao_version": versions["openmdao"],
        "scipy_version": versions["scipy"],
        "samples_count": len(per_sample),
        "best_dv_mps": best["dv_mps"] if best else None,
        "best_m_payload_kg": best["m_payload_kg"] if best else None,
        "artifacts": {
            "meta": os.path.basename(meta_path),
            "trade_ndjson": os.path.basename(trade_path),
        },
    }
    sys.stderr.write(
        "OPENMDAO_MISSION_RESULT "
        + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if meta["ok"] else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
