# pvlib_clearsky.py — ①b domain adapter (demiurge design.md D72)
# pvlib clear-sky producer for `energy + analyze`.
#
# D72 2-layer restructure: this file is now a THIN domain adapter.
# It owns ONLY the domain-specific site + PV-system spec (Phoenix AZ,
# Canadian Solar module, ABB inverter, 2024 calendar) and the domain
# honesty caveats. All clear-sky + ModelChain math is delegated to
# the shared ①a kernel `kernels/solar/pvlib_kernel.py`.
#
# SSOT location: `~/core/hexa-lang/stdlib/energy/pvlib_clearsky.py`
# (D61 — producer scripts live under hexa-lang/stdlib/<domain>/).
#
# Invoked by Swift's EnergyAnalyzeProducer via:
#   python3 ~/core/hexa-lang/stdlib/energy/pvlib_clearsky.py <output_dir>
#
# What it does (honest scope):
#   1. Construct a deterministic site (Phoenix, AZ — 33.4484 N /
#      112.074 W, alt 331 m) and standard PV system (Canadian Solar
#      CS5P_220M module + ABB micro inverter, fixed-tilt 33.4° south,
#      1 string × 1 module) — this is the ①b domain knowledge.
#   2. Delegates the Ineichen clear-sky run + CEC SAPM ModelChain for
#      the full 2024 calendar (8784 hourly steps) to the ①a kernel
#      `pvlib_kernel.run_clearsky_modelchain`.
#   3. Receives annual_energy_kwh (AC), annual_energy_dc_kwh, peak
#      power figures, GHI total, and a 12-month breakdown from the
#      kernel.
#   4. Emit pv_clearsky.meta.json with parameters + measurements +
#      pvlib version + Python version so cross-host drift is visible.
#
# HONESTY (g3 — non-negotiable, domain caveats stay HERE):
#   • Clear-sky output IS the measurement — the ①a kernel's pvlib
#     Ineichen + CEC SAPM algorithms are NREL SAM-verified. The
#     numbers are real algorithm outputs, not toy estimates.
#   • BUT there is NO sky-measured irradiance data — this is the
#     *clear-sky upper bound*, not a TMY yield simulation. Real-world
#     annual yield is typically 70-85 % of the clear-sky bound (cloud
#     cover, aerosol variability, snow soiling). measurement_gate
#     stays GATE_OPEN ALWAYS until TMY3 / NSRDB data is wired in.
#   • absorbed = false ALWAYS — pvlib is BSD-3 OSS but EXTERNAL.
#     "absorbed" requires (a) bench-validated module I-V curves AND
#     (b) site-measured irradiance time series. Neither is in scope.
#     The day a hexa-native clear-sky kernel re-computes these, the
#     flip happens in the ①a kernel — not in this adapter.
#   • No system losses applied (DC wiring, mismatch, soiling) — these
#     would push numbers DOWN, so the clear-sky bound is honestly
#     optimistic. scope_caveats embeds this.

import json
import os
import platform
import sys
import warnings

# --- Locate the ①a solar kernel relative to this adapter's own file
# (stdlib/energy/ -> stdlib/kernels/solar/). The Swift spawn sets an
# arbitrary cwd, so a path relative to __file__ is the only robust
# anchor.
_KERNEL_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "kernels", "solar")
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

# pvlib + pandas emit deprecation chatter we don't want polluting the
# producer summary line (honest: we want clean stderr for parsing).
warnings.filterwarnings("ignore")

# --- Standard site (Phoenix AZ — chosen for low cloud cover, high DNI,
#     which makes the clear-sky bound representative of a real high-
#     yield desert PV deployment). — this is the ①b domain knowledge.
GEOMETRY_ID = "pv_clearsky_phoenix_az_v1"
SITE_NAME = "Phoenix_AZ"
LATITUDE = 33.4484
LONGITUDE = -112.0740
ALTITUDE_M = 331.0
TIMEZONE = "America/Phoenix"

# --- Standard module + inverter (CEC database — canonical SAM picks).
MODULE_NAME = "Canadian_Solar_Inc__CS5P_220M"
INVERTER_NAME = "ABB__MICRO_0_25_I_OUTD_US_208__208V_"

# --- Mount + array geometry.
SURFACE_TILT = 33.4484          # lat-tilt rule (annual-optimal for fixed)
SURFACE_AZIMUTH = 180.0         # due-south (northern hemisphere)
MODULES_PER_STRING = 1
STRINGS = 1

# --- Simulation horizon (full year, hourly).
SIM_YEAR = 2024                 # leap year → 8784 steps
SIM_FREQ = "1h"

# --- Weather constants (clear-sky has no temperature data — use STC
#     ambient as honest placeholder; scope_caveats records the gap).
TEMP_AIR_C = 25.0
WIND_SPEED_MS = 1.0


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: pvlib_clearsky.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")
    csv_path = os.path.join(output_dir, f"{GEOMETRY_ID}.csv")
    py_v = platform.python_version()

    # Import the ①a kernel — honest gap if the kernel module is missing.
    try:
        import pvlib_kernel as kernel
    except ImportError as exc:
        sys.stderr.write(
            f"pvlib_clearsky: ①a solar kernel import failed — {exc}. "
            "Expected at stdlib/kernels/solar/pvlib_kernel.py (g3 — "
            "silent success forbidden).\n")
        summary = {"ok": False, "geometry_id": GEOMETRY_ID,
                   "error": "solar_kernel_import_failed"}
        sys.stderr.write("ENERGY_PVLIB_RESULT "
                         + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    pvlib_v = kernel.pvlib_version()

    # --- Delegate ALL clear-sky + ModelChain math to the ①a kernel.
    site = {
        "name": SITE_NAME, "latitude": LATITUDE, "longitude": LONGITUDE,
        "altitude_m": ALTITUDE_M, "timezone": TIMEZONE,
    }
    system = {
        "module": MODULE_NAME, "inverter": INVERTER_NAME,
        "surface_tilt": SURFACE_TILT, "surface_azimuth": SURFACE_AZIMUTH,
        "modules_per_string": MODULES_PER_STRING, "strings": STRINGS,
        "temp_air_C": TEMP_AIR_C, "wind_speed_ms": WIND_SPEED_MS,
    }
    sim = {"year": SIM_YEAR, "freq": SIM_FREQ}

    try:
        measurements = kernel.run_clearsky_modelchain(
            site, system, sim, csv_path)
        ok = True
        err = None
    except Exception as exc:
        ok = False
        err = f"{type(exc).__name__}: {exc}"
        measurements = {"rows": 0, "annual_energy_kwh": None,
                        "annual_energy_dc_kwh": None,
                        "dc_peak_kw": None, "ac_peak_kw": None,
                        "ghi_annual_mwh_per_m2": None,
                        "monthly_ac_kwh": {}, "csv_artifact": None}

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "pvlib_version": pvlib_v,
        "python_version": py_v,
        "error": err,
        "site": {
            "name": SITE_NAME,
            "latitude": LATITUDE,
            "longitude": LONGITUDE,
            "altitude_m": ALTITUDE_M,
            "timezone": TIMEZONE,
        },
        "system": {
            "module": MODULE_NAME,
            "inverter": INVERTER_NAME,
            "surface_tilt": SURFACE_TILT,
            "surface_azimuth": SURFACE_AZIMUTH,
            "modules_per_string": MODULES_PER_STRING,
            "strings": STRINGS,
            "temp_air_C": TEMP_AIR_C,
            "wind_speed_ms": WIND_SPEED_MS,
        },
        "simulation": {
            "year": SIM_YEAR,
            "freq": SIM_FREQ,
            "model": "clearsky_ineichen+cec_sapm",
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
        f"energy_pvlib: wrote {meta_path} (ok={ok}, "
        f"rows={measurements['rows']}, "
        f"annual_kwh={measurements['annual_energy_kwh']})\n")
    if not ok:
        sys.stderr.write(f"energy_pvlib: error → {err}\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "pvlib_version": pvlib_v,
        "python_version": py_v,
        "rows": measurements["rows"],
        "annual_energy_kwh": measurements["annual_energy_kwh"],
        "annual_energy_dc_kwh": measurements["annual_energy_dc_kwh"],
        "dc_peak_kw": measurements["dc_peak_kw"],
        "ac_peak_kw": measurements["ac_peak_kw"],
        "ghi_annual_mwh_per_m2": measurements["ghi_annual_mwh_per_m2"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("ENERGY_PVLIB_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
