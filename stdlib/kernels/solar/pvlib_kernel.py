# pvlib_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic solar clear-sky + PV-system computation kernel.
# Extracted under the D72 2-layer STDLIB restructure: any producer in
# `stdlib/<domain>/` that runs a pvlib clear-sky / PV ModelChain
# simulation calls into this single module instead of re-implementing
# the pvlib + pandas wrapping.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No Phoenix site, no
#                Canadian Solar module, no 2024 calendar — only "given
#                a site + a PV system spec + a time window, run the
#                Ineichen clear-sky model + CEC SAPM ModelChain and
#                reduce the result to energy facts".
#   ①b adapter — `stdlib/energy/pvlib_clearsky.py` (the Phoenix site /
#                module + inverter picks / year horizon / honesty
#                caveats), and any future solar-domain adapter. They
#                own the site + system + caveats and call this kernel
#                for the simulation.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * Clear-sky output IS the measurement — pvlib's Ineichen + CEC
#     SAPM algorithms are NREL SAM-verified (canonical reference solar
#     simulation in industry). The numbers are real algorithm outputs,
#     not toy estimates.
#   * BUT there is NO sky-measured irradiance data — this is the
#     *clear-sky upper bound*, not a TMY yield simulation. The honesty
#     gate (measurement_gate, scope_caveats, the clear-sky-vs-TMY
#     distinction, the no-system-loss caveat) lives in the ①b
#     adapter, NOT here.
#   * absorbed = false ALWAYS at the record layer — pvlib is an
#     EXTERNAL Python library, not absorbed into hexa-lang. The day a
#     hexa-native clear-sky kernel re-computes these spectra, absorbed
#     flips — and it flips HERE (one kernel) rather than in N domain
#     adapters.
#   * Import failure / simulation failure is raised, not swallowed —
#     silent success is forbidden. The caller reports it verbatim.

from typing import Any


def pvlib_version() -> str:
    """Probe the installed pvlib version string. Returns 'unknown' if
    the library cannot be imported — the caller decides whether that
    is a hard gap (it is, for solar producers)."""
    try:
        import pvlib
        return pvlib.__version__
    except Exception:
        return "unknown"


def run_clearsky_modelchain(site: dict, system: dict, sim: dict,
                            csv_path: str) -> dict:
    """Run the full pvlib clear-sky ModelChain for a given site +
    PV-system spec + simulation window, write the hourly DC/AC time
    series to `csv_path`, and return an energy-facts summary dict.

    Args:
        site   — {latitude, longitude, altitude_m, timezone, name}.
        system — {module, inverter, surface_tilt, surface_azimuth,
                  modules_per_string, strings, temp_air_C,
                  wind_speed_ms}.
        sim    — {year, freq}.
        csv_path — where to write the hourly dc_W / ac_W series CSV.

    Returns a dict mirroring the legacy energy `measurements` shape:
    rows, annual_energy_kwh, annual_energy_dc_kwh, dc/ac peak,
    ghi_annual_mwh_per_m2, monthly_ac_kwh, csv_artifact.

    Raises on import / library failure — the ①b adapter catches and
    reports the honest gap (g3 — silent success forbidden).
    """
    import os
    import pvlib
    from pvlib.location import Location
    from pvlib.pvsystem import PVSystem, retrieve_sam
    from pvlib.modelchain import ModelChain
    import pandas as pd

    loc = Location(
        latitude=site["latitude"], longitude=site["longitude"],
        tz=site["timezone"], altitude=site["altitude_m"],
        name=site["name"],
    )

    mods = retrieve_sam("CECMod")
    invs = retrieve_sam("CECInverter")
    module_name = system["module"]
    inverter_name = system["inverter"]
    if module_name not in mods:
        raise KeyError(f"module not in CECMod: {module_name}")
    if inverter_name not in invs:
        raise KeyError(f"inverter not in CECInverter: {inverter_name}")
    mod = mods[module_name]
    inv = invs[inverter_name]

    mount = pvlib.pvsystem.FixedMount(
        surface_tilt=system["surface_tilt"],
        surface_azimuth=system["surface_azimuth"])
    temp_params = pvlib.temperature.TEMPERATURE_MODEL_PARAMETERS[
        "sapm"]["open_rack_glass_glass"]
    array = pvlib.pvsystem.Array(
        mount=mount,
        module_parameters=mod,
        temperature_model_parameters=temp_params,
        modules_per_string=system["modules_per_string"],
        strings=system["strings"],
    )
    pv_system = PVSystem(arrays=[array], inverter_parameters=inv)
    mc = ModelChain(pv_system, loc, aoi_model="physical",
                    spectral_model="no_loss")

    year = sim["year"]
    times = pd.date_range(
        f"{year}-01-01", f"{year}-12-31 23:00",
        freq=sim["freq"], tz=loc.tz)
    cs = loc.get_clearsky(times)   # Ineichen + Linke turbidity
    weather = pd.DataFrame({
        "ghi": cs["ghi"], "dni": cs["dni"], "dhi": cs["dhi"],
        "temp_air": system["temp_air_C"],
        "wind_speed": system["wind_speed_ms"],
    }, index=times)
    mc.run_model(weather)

    dc = mc.results.dc
    ac = mc.results.ac
    # ModelChain returns DC as a DataFrame (single-array systems) with
    # a 'p_mp' column, or a Series if old API. Handle both.
    if hasattr(dc, "columns") and "p_mp" in getattr(dc, "columns", []):
        dc_p = dc["p_mp"]
    elif hasattr(dc, "p_mp"):
        dc_p = dc.p_mp
    else:
        dc_p = dc

    # Hourly W → kWh = W * 1h / 1000.
    dc_kwh = float(dc_p.sum()) / 1000.0
    ac_kwh = float(ac.sum()) / 1000.0
    dc_peak_kw = float(dc_p.max()) / 1000.0
    ac_peak_kw = float(ac.max()) / 1000.0

    # 12-month AC breakdown (kWh per calendar month).
    ac_monthly = (ac.groupby(ac.index.month).sum() / 1000.0).round(3)
    monthly_kwh = {int(m): float(v) for m, v in ac_monthly.items()}

    ghi_total_mwh_m2 = float(cs["ghi"].sum()) / 1000.0   # kWh → MWh per m²

    # Persist the hourly DC/AC series to CSV so downstream sweeps can
    # re-aggregate without re-running.
    series = pd.DataFrame({"dc_W": dc_p, "ac_W": ac}, index=times)
    series.to_csv(csv_path, index_label="timestamp")

    return {
        "rows": int(len(times)),
        "annual_energy_kwh": round(ac_kwh, 3),
        "annual_energy_dc_kwh": round(dc_kwh, 3),
        "dc_peak_kw": round(dc_peak_kw, 6),
        "ac_peak_kw": round(ac_peak_kw, 6),
        "ghi_annual_mwh_per_m2": round(ghi_total_mwh_m2, 3),
        "monthly_ac_kwh": monthly_kwh,
        "csv_artifact": os.path.basename(csv_path),
    }
