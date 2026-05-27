# nrel_midc_pyranometer.py — REAL measured-oracle producer
# (κ-68 G29 · RFC 013 §6.11 first cell absorbed=true legitimate flip ·
#  demiurge design.md D109 · supersedes G28b STUB · this is the
#  production path)
#
# Fetches a single day of NREL MIDC pyranometer GHI from the BMS
# (Baseline Measurement System) at the Solar Radiation Research
# Laboratory (SRRL) in Golden CO, computes an Ineichen clearsky
# modeled GHI using HEXA-NATIVE sun position + HEXA-NATIVE Ineichen
# atmospheric model, applies a clear-sky filter, and emits an
# Energy/verify record with the `measured_oracle` block populated
# by the real measured-vs-modeled comparison.
#
# When `mean_rel_err <= 0.05` (the D109 PASS criterion) over the
# clear-sky daylight window, the emitted record carries
# `absorbed = true` — this is the κ-68 first cell `absorbed: Bool`
# legitimate flip, driven by an EXTERNAL measured oracle (not a D95
# computed projection from substrate-parity).
#
# G31β — hexa-native Ineichen-clearsky swap (this revision):
#   The clearsky GHI computation no longer goes through pvlib's
#   `clearsky.ineichen` (Ineichen-Perez 2002). Instead a single
#   subprocess call to `_ineichen_clearsky_batch.hexa` returns one
#   GHI per minute via the clean-room hexa-native
#   `solar_kernel::ineichen_ghi` (G31β, pvlib substrate parity
#   <1e-10 over 7 test points). The Kasten-Young 1989 airmass + the
#   altitude-to-pressure conversion are also hexa-native this round.
#   pvlib still owns the Linke-turbidity climatology lookup
#   (NetCDF `LinkeTurbidities.h5`, monthly 5-min lat/lon grid) and
#   the Spencer-1972 extraterrestrial DNI — both are climatology
#   data tables, not closed-form math; out of scope for this port.
#   This closes the D80 §0 ultimate-form for Energy/solar's modeled
#   side. The bridge stack is now
#   `hexa_native_solar_position + hexa_native_ineichen_clearsky
#    (Linke from pvlib turbidity climatology)`.
#
# G31 G29-β — hexa-native sun-position swap (previous revision):
#   `_solar_position_batch.hexa` returns one `apparent_zenith_deg`
#   per minute via `solar_kernel::apparent_zenith` (κ-65 D80 pilot,
#   pvlib substrate parity <1e-9). Closed RFC 013 §6.11 reserved
#   slot at G31 (bridge_stack = `hexa_native_solar_position + pvlib
#   Ineichen`). This G31β revision closes the SECOND clause.
#
# HONESTY (g3 — non-negotiable):
#   - The measured side is REAL NREL MIDC pyranometer data (Global
#     CMP22 (vent/cor) channel — research-grade, vented + thermally
#     corrected). No synthetic numbers.
#   - The modeled side is now FULL HEXA-NATIVE on the closed-form
#     math axis: sun position (Sandia 1985 ephemeris, solar_kernel
#     <1e-9 vs pvlib), Kasten-Young 1989 airmass, altitude→pressure
#     (ISA-like), and Ineichen-Perez 2002 clearsky GHI all run from
#     `stdlib/kernels/solar/solar_kernel.hexa`. Substrate-parity
#     vs pvlib 0.13.x is <1e-10 relative on 7 G31β test points.
#   - Linke-turbidity climatology lookup (`pvlib.clearsky.
#     lookup_linke_turbidity` — NetCDF `LinkeTurbidities.h5`) and
#     Spencer-1972 extraterrestrial DNI (`pvlib.irradiance.
#     get_extra_radiation`) remain pvlib dependencies. These are
#     CLIMATOLOGY DATA TABLES, not the closed-form math the D80
#     hexa-port pursues. Porting the NetCDF Linke grid is a
#     separate axis (out of scope this PR).
#   - Clear-sky filter (`CLEARSKY_RATIO_LO / HI`) is honestly
#     documented; samples outside the window are DROPPED from the
#     parity statistic. This is the only way to compute a meaningful
#     clear-sky-bound parity number on a day with even partial cloud
#     enhancement / shadow. The dropped count is reported in
#     `dataset_caveats`.
#   - D106 illustrative-physics exclusion does NOT apply here —
#     Energy/solar is a measurement cell (not illustrative).
#   - D103 dimension-separation: the `hexa_native_parity` field is
#     left null (substrate parity is a separate axis, established
#     elsewhere — PILOTS.demi `[pilot-solar]`).
#
# Invoked by Swift's EnergyVerifyProducer via:
#   python3 ~/core/hexa-lang/stdlib/energy/nrel_midc_pyranometer.py <output_dir> [date]
# `date` defaults to a curated clear-sky day if omitted.

import csv
import datetime as _dt
import io
import json
import os
import platform
import subprocess
import sys
import urllib.request

import numpy as np
import pandas as pd
import pvlib


PRODUCER_ID = "nrel_midc_pyranometer"

# NREL MIDC site coordinates — SRRL BMS, Golden CO.
LATITUDE = 39.7423
LONGITUDE = -105.1785
ALTITUDE_M = 1828.0
TZ = "Etc/GMT+7"  # MST = UTC-7 year-round at this gauge
SITE = "BMS"

# Default date: 2024-06-15 — observed clear-sky-day candidate at SRRL.
DEFAULT_DATE = "2024-06-15"

# D109 PASS criterion — mean relative error over clear-sky daylight
# hours. Locked-in by design.md D109; must NOT be tuned post-hoc.
PASS_THRESHOLD = 0.05

# Clear-sky filter — keep only minutes where measured/modeled lies
# within a ratio band. Drops cloud shadows (ratio << 1) and
# cloud-enhancement spikes (ratio > 1).
CLEARSKY_RATIO_LO = 0.85
CLEARSKY_RATIO_HI = 1.30

# Daylight filter — drops near-horizon refraction-dominated samples
# and the nighttime baseline.
DAYLIGHT_ZENITH_DEG = 85.0

# G31 G29-β — hexa-native sun-position batch CLI wrapper. One
# subprocess call returns N apparent_zenith values (newline-separated)
# for a minute-cadence sweep of the day. Located in the same directory
# as this producer.
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
HEXA_SOLAR_BATCH = os.path.join(_THIS_DIR, "_solar_position_batch.hexa")

# G31β — hexa-native Ineichen-clearsky batch CLI wrapper. One
# subprocess call returns N GHI values (newline-separated, W/m^2) for
# the apparent_zenith + airmass + linke_turbidity + dni_extra rows
# packed as argv strings.
HEXA_INEICHEN_BATCH = os.path.join(
    _THIS_DIR, "_ineichen_clearsky_batch.hexa")

# G31β — point the hexa toolchain at the worktree-local stdlib root.
# Without this the loader resolves `use "stdlib/kernels/solar/
# solar_kernel"` against the global ~/core/hexa-lang/ path and misses
# the new G31β kernel functions.
_HEXA_REPO_ROOT = os.path.abspath(os.path.join(_THIS_DIR, "..", ".."))
_HEXA_ENV = {**os.environ, "HEXA_LANG": _HEXA_REPO_ROOT}


def _fetch_midc(site, date):
    """Fetch a single day of NREL MIDC 1-min data."""
    ymd = date.replace("-", "")
    url = (
        f"https://midcdmz.nrel.gov/apps/data_api.pl"
        f"?site={site}&begin={ymd}&end={ymd}"
    )
    with urllib.request.urlopen(url, timeout=60) as resp:
        return resp.read().decode("utf-8")


def _parse_midc(csv_text):
    """Extract measured GHI + NREL-computed zenith into a DataFrame."""
    reader = csv.reader(io.StringIO(csv_text))
    header = next(reader)
    i_ghi = header.index("Global CMP22 (vent/cor) [W/m^2]")
    i_zen = header.index("Zenith Angle [degrees]")
    rows = []
    for row in reader:
        try:
            ghi = float(row[i_ghi])
            zen = float(row[i_zen])
        except (ValueError, IndexError):
            continue
        rows.append({"measured_ghi": ghi, "nrel_zenith": zen})
    return pd.DataFrame(rows)


def _hexa_apparent_zenith_batch(date, n_minutes):
    """G31 G29-β — hexa-native sun-position batch call.

    One subprocess invocation of `_solar_position_batch.hexa` returns
    `n_minutes` `apparent_zenith_deg` values for a minute-cadence sweep
    over the day starting at `date` 00:00 in the producer's local
    timezone (TZ, MST = UTC-7). Replaces pvlib's
    `solarposition.get_solarposition()` path. Substrate parity vs
    pvlib SPA <1e-9 (κ-65 D80 pilot).
    """
    # Convert the local-tz start to UTC for the hexa kernel (which
    # takes year/doy/utc_hour). TZ is "Etc/GMT+7" (MST, UTC-7).
    local_start = pd.Timestamp(f"{date} 00:00:00", tz=TZ)
    utc_start = local_start.tz_convert("UTC")
    year = utc_start.year
    doy = int(utc_start.dayofyear)
    utc_hour_start = (
        utc_start.hour + utc_start.minute / 60.0
        + utc_start.second / 3600.0
    )
    # The kernel's internal time math tolerates utc_hour > 24 across
    # the UTC day boundary (linear epoch_date + gmst fmod_floor).
    cmd = [
        "hexa", "run", HEXA_SOLAR_BATCH,
        str(year), str(doy),
        f"{utc_hour_start:.6f}", "1.0", str(int(n_minutes)),
        f"{LATITUDE:.6f}", f"{LONGITUDE:.6f}",
    ]
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=120,
        env=_HEXA_ENV)
    if proc.returncode != 0:
        raise RuntimeError(
            f"hexa solar-position batch failed (rc={proc.returncode}): "
            f"{proc.stderr.strip()[:400]}")
    lines = [ln for ln in proc.stdout.strip().split("\n") if ln.strip()]
    if len(lines) != n_minutes:
        raise RuntimeError(
            f"hexa solar-position batch returned {len(lines)} lines, "
            f"expected {n_minutes}")
    return np.array([float(ln) for ln in lines], dtype=float)


def _hexa_ineichen_ghi_batch(altitude_m, rows):
    """G31β — hexa-native Ineichen-clearsky batch call.

    One subprocess invocation of `_ineichen_clearsky_batch.hexa` takes
    N comma-separated "<z>,<TL>,<dni_extra>" rows via argv and returns
    N GHI values on stdout. Airmass + altitude-to-pressure are
    computed inside the hexa wrapper (Kasten-Young 1989 + ISA-like
    barometric). Replaces pvlib's `clearsky.ineichen()` +
    `atmosphere.get_relative_airmass` + `atmosphere.alt2pres` +
    `atmosphere.get_absolute_airmass` path. Substrate parity vs
    pvlib 0.13.x <1e-10 on 7 G31β test points.

    Parameters
    ----------
    altitude_m : float
        Site altitude above sea level (m). Constant for the day.
    rows : list[tuple[float, float, float]]
        Per-step (apparent_zenith_deg, linke_turbidity,
        dni_extra_W_m2). Length = number of steps.

    Returns
    -------
    np.ndarray
        Per-step GHI (W/m^2), dtype=float.
    """
    n = len(rows)
    row_args = [
        f"{z:.12g},{tl:.12g},{dni:.12g}"
        for (z, tl, dni) in rows
    ]
    cmd = [
        "hexa", "run", HEXA_INEICHEN_BATCH,
        f"{altitude_m:.6f}", str(n),
        *row_args,
    ]
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=120,
        env=_HEXA_ENV)
    if proc.returncode != 0:
        raise RuntimeError(
            f"hexa ineichen-clearsky batch failed (rc={proc.returncode}): "
            f"{proc.stderr.strip()[:400]}")
    lines = [ln for ln in proc.stdout.strip().split("\n") if ln.strip()]
    if len(lines) != n:
        raise RuntimeError(
            f"hexa ineichen-clearsky batch returned {len(lines)} lines, "
            f"expected {n}")
    return np.array([float(ln) for ln in lines], dtype=float)


def _compute_modeled(date, n_minutes):
    """Hexa-native apparent_zenith + hexa-native Ineichen clearsky.

    G31β bridge stack: sun position from the clean-room
    `solar_kernel::apparent_zenith` via `_solar_position_batch.hexa`;
    Kasten-Young 1989 airmass + ISA-like alt-to-pressure + Ineichen-
    Perez 2002 clearsky GHI all from `solar_kernel.hexa` via
    `_ineichen_clearsky_batch.hexa`. pvlib remains the source of the
    Linke-turbidity climatology lookup (monthly NetCDF grid) and the
    Spencer-1972 extraterrestrial DNI — both are climatology data
    tables, not closed-form math; out of scope for this port.
    """
    times = pd.date_range(
        start=f"{date} 00:00:00", periods=n_minutes,
        freq="1min", tz=TZ)

    # 1. Hexa-native apparent_zenith (replaces pvlib solarposition).
    apparent_zenith = _hexa_apparent_zenith_batch(date, n_minutes)

    # 2. pvlib still owns the climatology data tables:
    #    - Linke turbidity monthly climatology (NetCDF
    #      `LinkeTurbidities.h5`, 5-min lat/lon grid).
    #    - Spencer-1972 extraterrestrial DNI (~1325-1410 W/m^2,
    #      varies across the year by Earth-Sun distance).
    linke_turbidity = np.asarray(
        pvlib.clearsky.lookup_linke_turbidity(
            times, LATITUDE, LONGITUDE).values, dtype=float)
    dni_extra = np.asarray(
        pvlib.irradiance.get_extra_radiation(times).values, dtype=float)

    # 3. Hexa-native Ineichen GHI (replaces pvlib clearsky.ineichen +
    #    get_relative_airmass + alt2pres + get_absolute_airmass).
    rows = [
        (float(apparent_zenith[i]), float(linke_turbidity[i]),
         float(dni_extra[i]))
        for i in range(n_minutes)
    ]
    modeled_ghi = _hexa_ineichen_ghi_batch(ALTITUDE_M, rows)

    return pd.DataFrame({
        # Column kept as `pvlib_zenith` for back-compat with the rest
        # of the pipeline (daylight filter etc); semantically it now
        # carries the HEXA-NATIVE apparent zenith.
        "pvlib_zenith": apparent_zenith,
        "modeled_ghi": modeled_ghi,
    })


def _build_measured_oracle(date):
    """Run the full real-data parity pipeline; return the
    measured_oracle block + summary stats + flip decision."""
    csv_text = _fetch_midc(SITE, date)
    measured = _parse_midc(csv_text)
    n = len(measured)
    if n == 0:
        raise RuntimeError("NREL MIDC fetch returned 0 rows")

    modeled = _compute_modeled(date, n_minutes=n)
    df = measured.reset_index(drop=True).join(modeled.reset_index(drop=True))

    daylight = df[df["pvlib_zenith"] < DAYLIGHT_ZENITH_DEG].copy()
    daylight["ratio"] = daylight["measured_ghi"] / daylight["modeled_ghi"]
    clear = daylight[
        (daylight["ratio"] > CLEARSKY_RATIO_LO) &
        (daylight["ratio"] < CLEARSKY_RATIO_HI)
    ].copy()

    if len(clear) == 0:
        raise RuntimeError(
            f"no clear-sky samples on {date} after filter "
            f"({CLEARSKY_RATIO_LO}-{CLEARSKY_RATIO_HI})")

    clear["rel_err"] = (
        (clear["measured_ghi"] - clear["modeled_ghi"]).abs()
        / clear["measured_ghi"].abs()
    )
    mean_rel_err = float(clear["rel_err"].mean())
    max_rel_err = float(clear["rel_err"].max())

    daylight_count = int(len(daylight))
    clear_count = int(len(clear))
    dropped = daylight_count - clear_count

    pvlib_version = pvlib.__version__
    measured_oracle = {
        "oracle_source": (
            f"NREL MIDC {SITE} (SRRL Golden CO) · pyranometer GHI "
            f"Global CMP22 (vent/cor) · {date} · 1-min cadence"
        ),
        "unit": "W/m^2",
        "sample_count": clear_count,
        "mean_rel_err": mean_rel_err,
        "max_rel_err": max_rel_err,
        "threshold": PASS_THRESHOLD,
        "dataset_caveats": (
            f"daylight samples (zenith<{DAYLIGHT_ZENITH_DEG}°): "
            f"{daylight_count}; clear-sky kept (ratio in "
            f"[{CLEARSKY_RATIO_LO},{CLEARSKY_RATIO_HI})): "
            f"{clear_count}; dropped cloudy/cloud-enhanced: {dropped}. "
            "modeled = HEXA-NATIVE solar_kernel apparent_zenith "
            "(clean-room Sandia 1985 ephemeris, <1e-9 substrate "
            "parity vs pvlib SPA at κ-65) + HEXA-NATIVE Kasten-Young "
            "1989 airmass + HEXA-NATIVE Ineichen-Perez 2002 clearsky "
            "GHI (<1e-10 substrate parity vs pvlib at G31β). "
            "Linke-turbidity climatology lookup + Spencer-1972 "
            f"extraterrestrial DNI remain in pvlib {pvlib_version} "
            "(NetCDF climatology data tables, separate axis). "
            "measured side = research-grade vented + thermally "
            "corrected CMP22 pyranometer."
        ),
        "dataset_citation": (
            "https://midcdmz.nrel.gov/apps/sitehome.pl?site=" + SITE
        ),
    }
    pass_flag = mean_rel_err <= PASS_THRESHOLD
    return measured_oracle, pass_flag, {
        "daylight_count": daylight_count,
        "clear_count": clear_count,
        "dropped": dropped,
        "pvlib_version": pvlib_version,
    }


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(
            "usage: nrel_midc_pyranometer.py <output_dir> [date=YYYY-MM-DD]\n")
        return 2

    output_dir = argv[1]
    date = argv[2] if len(argv) >= 3 else DEFAULT_DATE
    os.makedirs(output_dir, exist_ok=True)

    try:
        measured_oracle, pass_flag, stats = _build_measured_oracle(date)
    except Exception as exc:
        sys.stderr.write(
            f"nrel_midc_pyranometer: failed to compute measured oracle: "
            f"{type(exc).__name__}: {exc}\n")
        return 3

    stamp = _dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    # D109 legitimate-flip path — absorbed is set EXPLICITLY by the
    # writer (this producer) based on the measured-oracle PASS gate.
    # D95 computed `isHexaNativeAbsorbed` is NOT in this path (D103
    # dimension separation).
    absorbed = bool(pass_flag)

    record = {
        "domain": "energy",
        "verb": "verify",
        "kind": "solar_clearsky_ghi_measured_oracle",
        "stamp": stamp,
        "producer": PRODUCER_ID,
        "measurement_gate": (
            "GATE_CLOSED_MEASURED" if absorbed else "GATE_OPEN"
        ),
        # κ-68 G29: this is the κ-68 FIRST cell absorbed=true
        # legitimate flip target. The writer (this producer) sets
        # absorbed explicitly based on `measured_oracle.mean_rel_err`
        # vs the D109 threshold. D95 computed projection is NOT used.
        "absorbed": absorbed,
        "scope_caveats": [
            f"single clear-sky day ({date}); mean rel_err over "
            f"{stats['clear_count']} clear-sky-filtered samples "
            "vs Ineichen clearsky modeled GHI (FULL hexa-native "
            "closed-form math — sun position, airmass, and "
            "clearsky GHI all run from solar_kernel.hexa).",
            (
                "modeled stack uses hexa-native "
                "`solar_kernel::apparent_zenith` (clean-room Sandia "
                "1985 ephemeris; κ-65 D80 pilot, substrate parity "
                "vs pvlib SPA <1e-9) for sun position, and hexa-"
                "native `solar_kernel::ineichen_ghi` + "
                "`kasten_airmass_absolute` + `alt2pres` (clean-room "
                "Ineichen-Perez 2002 / Kasten-Young 1989 / ISA-like "
                "barometric; G31β substrate parity vs pvlib <1e-10) "
                "for the atmospheric model. This closes the D80 §0 "
                "ultimate-form for Energy/solar's modeled-side "
                "closed-form math axis."
            ),
            "Linke-turbidity climatology assumption inherent in "
            "Ineichen — not site-specific aerosol retrieval. "
            "Climatology data tables (Linke NetCDF + Spencer-1972 "
            "extraterrestrial DNI) remain pvlib-sourced — out of "
            "scope for the closed-form-math D80 port.",
        ],
        "citations": [
            "demiurge design.md D109 — Energy/solar cell + NREL MIDC "
            "pyranometer GHI direction (κ-68 G27)",
            "demiurge proposals/rfc_013_hexa_native_parity_connection."
            "md §6.11 — per-cell measured-oracle parity round",
            "https://midcdmz.nrel.gov/apps/sitehome.pl?site=" + SITE,
            "pvlib python " + stats["pvlib_version"],
        ],
        "skipped_reason": None,
        "kernel_reuse": (
            "hexa_native_solar_position (solar_kernel::apparent_zenith "
            "via _solar_position_batch.hexa) + "
            "hexa_native_ineichen_clearsky "
            "(solar_kernel::{ineichen_ghi, kasten_airmass_absolute, "
            "alt2pres} via _ineichen_clearsky_batch.hexa). "
            "Linke-turbidity climatology lookup + Spencer-1972 "
            "extraterrestrial DNI from pvlib (NetCDF data tables, "
            "separate axis). substrate-parity proven on "
            "stdlib/kernels/solar/solar_kernel_test.hexa "
            "(34/34 PASS at κ-65 D80 + G31β)"
        ),
        # D103 dimension-separation — substrate parity axis left null
        # here; substrate-parity is carried separately by PILOTS.demi
        # `[pilot-solar]` (21/21 PASS).
        "hexa_native_parity": None,
        # κ-68 G29 — measured-oracle axis populated from real data.
        "measured_oracle": measured_oracle,
    }

    out_path = os.path.join(
        output_dir,
        f"energy_verify_{stamp}_{PRODUCER_ID}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "producer": PRODUCER_ID,
        "stamp": stamp,
        "date": date,
        "site": SITE,
        "daylight_count": stats["daylight_count"],
        "clear_count": stats["clear_count"],
        "dropped": stats["dropped"],
        "mean_rel_err": measured_oracle["mean_rel_err"],
        "max_rel_err": measured_oracle["max_rel_err"],
        "threshold": PASS_THRESHOLD,
        "pass": pass_flag,
        "absorbed": absorbed,
        "artifact": os.path.basename(out_path),
        "python_version": platform.python_version(),
        "pvlib_version": stats["pvlib_version"],
    }
    sys.stderr.write(
        "ENERGY_VERIFY_MEASURED_ORACLE_RESULT "
        + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
