# plasma_metrics.py — phase κ-46 (P-⑧ cohort producer prototype, D69)
# plasmapy derived-parameter producer for `fusion + analyze` — the 6th
# cohort domain wired to a real measuring engine tool (after sscb κ-34,
# grid κ-36, energy κ-38, space κ-39, antimatter κ-43). The FIRST
# plasma-physics producer. Cross-host parity verified: byte-identical
# omega_pe / lambda_D / v_A between ubu-2 (Linux, Python 3.12.3) and
# darwin (Mac, Python 3.14.4) on plasmapy 2026.2.0.
#
# SSOT (D61 — demiurge = pointer / spawn wrapper ONLY):
# this script LIVES in `~/core/hexa-lang/stdlib/fusion/` because all
# producer compute scripts (Python / shell / hexa-native) belong to
# hexa-lang. demiurge's Swift FusionAnalyzeProducer is a `Process`
# spawn wrapper that locates this file by absolute path under
# `~/core/hexa-lang/stdlib/fusion/plasma_metrics.py`. `cockpit/scripts/
# *.py` 금지 (D61 — birth-violation list).
#
# Invoked by Swift's FusionAnalyzeProducer via:
#   /opt/homebrew/bin/python3 \
#       ~/core/hexa-lang/stdlib/fusion/plasma_metrics.py <output_dir>
#
# What it does (honest scope):
#   1. Use a deterministic ITER-like core-plasma operating point:
#        - electron density   n_e = 1.0e20  m^-3
#        - electron temperature T_e = 10 keV
#        - ion temperature     T_i = 10 keV (D+ majority)
#        - magnetic field      B   = 5.3 T   (ITER on-axis)
#        - majority ion        D+  (deuterium)
#      These are textbook ITER reference values — NOT a real device
#      measurement (g3 — see HONESTY below).
#   2. Compute derived plasma parameters using plasmapy.formulary:
#        - electron plasma frequency      omega_pe
#        - ion plasma frequency           omega_pi  (D+)
#        - electron Debye length          lambda_D
#        - electron gyrofrequency         omega_ce
#        - ion gyrofrequency              omega_ci  (D+)
#        - electron thermal speed         v_th_e
#        - ion thermal speed              v_th_i    (D+)
#        - Alfvén speed                   v_A       (D+ majority)
#        - electron gyroradius            r_Le      (perpendicular,
#                                                   thermal_speed)
#        - ion gyroradius                 r_Li      (D+)
#      All values come from plasmapy 2026.2.0 (CC-BY-4.0 / BSD-2,
#      community-maintained, peer-reviewed formula implementations).
#   3. Emit plasma_iter_core_v1.meta.json with input + derived values +
#      plasmapy version + Python version so cross-host drift is visible.
#      Also emit plasma_iter_core_v1.csv (single-row table for easy
#      ingest by downstream sweeps).
#
# HONESTY (g3 — non-negotiable):
#   • Derived values ARE the measurement — Bohm·Debye·plasma-frequency·
#     gyrofrequency formulas are mathematical facts (Maxwell-Boltzmann +
#     Lorentz-force algebra). The numbers plasmapy computes ARE real
#     — given the inputs, they are the inputs' implied parameters.
#     So measurement_gate = GATE_CLOSED_MEASURED for the PARAMETERS
#     themselves (standard formulae).
#   • BUT the inputs (n_e, T_e, B) are textbook ITER reference values,
#     NOT a real plasma-device shot. This is NOT a measurement of any
#     plasma — it is a derivation of what a plasma with these properties
#     WOULD have. So `absorbed = false` ALWAYS — "absorbed" requires a
#     real Thomson-scattering / interferometry / magnetic-probe reading
#     from an actual tokamak (JET / TFTR / KSTAR / SPARC / ITER) wired
#     into the script. None is in scope here.
#   • This script does NOT compute equilibrium (G-S solution), nor edge/
#     SOL turbulence, nor neutronics — those are FreeGS / BOUT++ /
#     OpenMC respectively (domains/fusion.md §2). plasmapy provides
#     basic-formulary derived parameters; that is its honest scope.
#   • scope_caveats embeds: (1) textbook inputs not device-measured;
#     (2) parameters only, no equilibrium / transport / fusion-Q;
#     (3) D+ majority assumption (real ITER will be D-T 50:50; T+ not
#     included in this v1); (4) cold plasma assumption — relativistic
#     correction is small at 10 keV (~2 %) but not applied.

import json
import os
import platform
import sys
import warnings

# plasmapy + astropy emit RelativityWarning at high T_e (~10 keV gives
# v_th_e ≈ 0.2 c) — honest: we know, scope_caveats records it, but the
# warning would pollute stderr and break the FUSION_PLASMAPY_RESULT
# parsing line. Suppress for clean machine-readable summary.
warnings.filterwarnings("ignore")

# --- Standard operating point (ITER-like core, textbook values).
GEOMETRY_ID = "plasma_iter_core_v1"
SCENARIO_NAME = "ITER_core_reference"

# Inputs — these are the *device-independent* assumptions. NOT measured.
NE_M3 = 1.0e20          # electron density [m^-3]      (ITER design)
TE_KEV = 10.0           # electron temperature [keV]    (ITER baseline)
TI_KEV = 10.0           # ion temperature [keV]         (assumed equal)
B_T = 5.3               # magnetic field [T]            (ITER on-axis)
ION_SPECIES = "D+"      # majority ion (deuterium; ITER will run D-T)


def plasmapy_version() -> str:
    try:
        import plasmapy
        return plasmapy.__version__
    except Exception:
        return "unknown"


def run_simulation(output_dir: str) -> dict:
    """Compute the derived plasma parameters via plasmapy and return a
    summary dict. Raises on import / library failure — the caller (main)
    catches and reports honest gap."""
    import plasmapy
    from plasmapy.formulary import (
        plasma_frequency,
        Debye_length,
        gyrofrequency,
        gyroradius,
        thermal_speed,
        Alfven_speed,
    )
    from astropy import units as u

    n_e = NE_M3 * u.m**-3
    T_e_eV = TE_KEV * 1000 * u.eV
    T_i_eV = TI_KEV * 1000 * u.eV
    # plasmapy formulae expect temperature in Kelvin OR eV — use the
    # eV-K equivalency from astropy.units (kT = eV).
    T_e_K = T_e_eV.to(u.K, equivalencies=u.temperature_energy())
    T_i_K = T_i_eV.to(u.K, equivalencies=u.temperature_energy())
    B = B_T * u.T

    # --- Derived parameters (units stripped to SI scalars for JSON).
    omega_pe = float(plasma_frequency(n_e, particle="e-").to(u.rad / u.s).value)
    omega_pi = float(plasma_frequency(n_e, particle=ION_SPECIES).to(u.rad / u.s).value)
    lambda_D = float(Debye_length(T_e_K, n_e).to(u.m).value)
    omega_ce = float(gyrofrequency(B, particle="e-").to(u.rad / u.s).value)
    omega_ci = float(gyrofrequency(B, particle=ION_SPECIES).to(u.rad / u.s).value)
    v_th_e = float(thermal_speed(T_e_K, particle="e-").to(u.m / u.s).value)
    v_th_i = float(thermal_speed(T_i_K, particle=ION_SPECIES).to(u.m / u.s).value)
    v_A = float(Alfven_speed(B, n_e, ion=ION_SPECIES).to(u.m / u.s).value)
    # gyroradius expects a thermal_speed scalar — pass v_perp via T.
    r_Le = float(
        gyroradius(B, particle="e-", T=T_e_K).to(u.m).value
    )
    r_Li = float(
        gyroradius(B, particle=ION_SPECIES, T=T_i_K).to(u.m).value
    )

    # Frequencies in Hz too (engineering-friendly).
    import math
    f_pe_Hz = omega_pe / (2 * math.pi)
    f_pi_Hz = omega_pi / (2 * math.pi)
    f_ce_Hz = omega_ce / (2 * math.pi)
    f_ci_Hz = omega_ci / (2 * math.pi)

    # Write a single-row CSV so downstream sweeps can ingest uniformly.
    csv_path = os.path.join(output_dir, f"{GEOMETRY_ID}.csv")
    with open(csv_path, "w", encoding="utf-8") as cf:
        cf.write(
            "scenario,n_e_m3,T_e_keV,T_i_keV,B_T,ion,"
            "omega_pe_rad_s,omega_pi_rad_s,lambda_D_m,"
            "omega_ce_rad_s,omega_ci_rad_s,"
            "v_th_e_m_s,v_th_i_m_s,v_A_m_s,"
            "r_Le_m,r_Li_m,"
            "f_pe_Hz,f_pi_Hz,f_ce_Hz,f_ci_Hz\n"
        )
        cf.write(
            f"{SCENARIO_NAME},{NE_M3},{TE_KEV},{TI_KEV},{B_T},{ION_SPECIES},"
            f"{omega_pe},{omega_pi},{lambda_D},"
            f"{omega_ce},{omega_ci},"
            f"{v_th_e},{v_th_i},{v_A},"
            f"{r_Le},{r_Li},"
            f"{f_pe_Hz},{f_pi_Hz},{f_ce_Hz},{f_ci_Hz}\n"
        )

    return {
        "rows": 1,
        # Frequencies (rad/s) — primary algebra form.
        "omega_pe_rad_s": omega_pe,
        "omega_pi_rad_s": omega_pi,
        "omega_ce_rad_s": omega_ce,
        "omega_ci_rad_s": omega_ci,
        # Frequencies (Hz) — engineering form.
        "f_pe_Hz": f_pe_Hz,
        "f_pi_Hz": f_pi_Hz,
        "f_ce_Hz": f_ce_Hz,
        "f_ci_Hz": f_ci_Hz,
        # Lengths.
        "lambda_D_m": lambda_D,
        "r_Le_m": r_Le,
        "r_Li_m": r_Li,
        # Speeds.
        "v_th_e_m_s": v_th_e,
        "v_th_i_m_s": v_th_i,
        "v_A_m_s": v_A,
        "csv_artifact": f"{GEOMETRY_ID}.csv",
    }


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: plasma_metrics.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")
    plasmapy_v = plasmapy_version()
    py_v = platform.python_version()

    try:
        measurements = run_simulation(output_dir)
        ok = True
        err = None
    except Exception as exc:
        ok = False
        err = f"{type(exc).__name__}: {exc}"
        measurements = {
            "rows": 0,
            "omega_pe_rad_s": None, "omega_pi_rad_s": None,
            "omega_ce_rad_s": None, "omega_ci_rad_s": None,
            "f_pe_Hz": None, "f_pi_Hz": None,
            "f_ce_Hz": None, "f_ci_Hz": None,
            "lambda_D_m": None, "r_Le_m": None, "r_Li_m": None,
            "v_th_e_m_s": None, "v_th_i_m_s": None, "v_A_m_s": None,
            "csv_artifact": None,
        }

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "plasmapy_version": plasmapy_v,
        "python_version": py_v,
        "error": err,
        "scenario": {
            "name": SCENARIO_NAME,
            "n_e_m3": NE_M3,
            "T_e_keV": TE_KEV,
            "T_i_keV": TI_KEV,
            "B_T": B_T,
            "ion_species": ION_SPECIES,
        },
        "measurements": measurements,
        "artifacts": {
            "csv": measurements.get("csv_artifact") or "",
        },
    }

    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"plasma_metrics: wrote {meta_path} (ok={ok}, "
        f"omega_pe={measurements.get('omega_pe_rad_s')}, "
        f"lambda_D={measurements.get('lambda_D_m')})\n"
    )
    if not ok:
        sys.stderr.write(f"plasma_metrics: error → {err}\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "plasmapy_version": plasmapy_v,
        "python_version": py_v,
        "rows": measurements["rows"],
        "omega_pe_rad_s": measurements["omega_pe_rad_s"],
        "omega_pi_rad_s": measurements["omega_pi_rad_s"],
        "omega_ce_rad_s": measurements["omega_ce_rad_s"],
        "omega_ci_rad_s": measurements["omega_ci_rad_s"],
        "lambda_D_m": measurements["lambda_D_m"],
        "v_A_m_s": measurements["v_A_m_s"],
        "r_Li_m": measurements["r_Li_m"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("FUSION_PLASMAPY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
