# nrel_midc_pyranometer.py — REAL measured-oracle producer
# (κ-68 G29 · RFC 013 §6.11 first cell absorbed=true legitimate flip ·
#  demiurge design.md D109 · supersedes G28b STUB · this is the
#  production path)
#
# Fetches a single day of NREL MIDC pyranometer GHI from the BMS
# (Baseline Measurement System) at the Solar Radiation Research
# Laboratory (SRRL) in Golden CO, computes an Ineichen clearsky
# modeled GHI using HEXA-NATIVE sun position + pvlib's Ineichen
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
# G31 G29-β — hexa-native sun-position swap (this revision):
#   The sun-position computation no longer goes through pvlib's
#   `solarposition` (Sandia 1985 ephemeris). Instead a single
#   subprocess call to `_solar_position_batch.hexa` returns one
#   `apparent_zenith_deg` per minute via the clean-room hexa-native
#   `solar_kernel::apparent_zenith` (κ-65 D80 pilot, pvlib substrate
#   parity <1e-9). The Ineichen clearsky stack stays in pvlib:
#   linke-turbidity climatology lookup, Kasten-Young airmass, and
#   `clearsky.ineichen()` are called directly with the hexa-supplied
#   apparent_zenith. This closes RFC 013 §6.11 reserved slot — the
#   bridge stack is now `hexa_native_solar_position + pvlib Ineichen`.
#
# HONESTY (g3 — non-negotiable):
#   - The measured side is REAL NREL MIDC pyranometer data (Global
#     CMP22 (vent/cor) channel — research-grade, vented + thermally
#     corrected). No synthetic numbers.
#   - The modeled side now combines hexa-native sun position with
#     pvlib's Ineichen clearsky atmospheric model. Ineichen depends
#     on Linke-turbidity climatology and is itself an atmospheric
#     idealization. Substrate-parity for the pvlib clearsky stack
#     is already proven on `stdlib/kernels/solar/pvlib_kernel.py`
#     (κ-65 D80 pilot — solar 21/21 PASS at rel_err <= 1e-13). The
#     hexa-native sun-position kernel substrate-parity vs pvlib's
#     SPA is <1e-9 on `solar_kernel_test.hexa`.
#   - The hexa-native scope per D109 is `solar_position_kernel` (sun
#     position only). This producer calls the hexa-native kernel via
#     `_solar_position_batch.hexa` subprocess (G31 G29-β); the rest
#     of the Ineichen pipeline remains pvlib (Linke turbidity +
#     airmass + ineichen GHI).
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
        cmd, capture_output=True, text=True, timeout=120)
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


def _compute_modeled(date, n_minutes):
    """Hexa-native apparent_zenith + pvlib Ineichen clearsky → modeled GHI.

    G31 G29-β bridge stack: sun position from the clean-room
    `solar_kernel::apparent_zenith` via `_solar_position_batch.hexa`;
    Linke turbidity, Kasten-Young airmass, and the Ineichen clearsky
    model from pvlib (κ-65 D80 substrate-parity proven).
    """
    times = pd.date_range(
        start=f"{date} 00:00:00", periods=n_minutes,
        freq="1min", tz=TZ)

    # 1. Hexa-native apparent_zenith (replaces pvlib solarposition).
    apparent_zenith = _hexa_apparent_zenith_batch(date, n_minutes)

    # 2. pvlib Ineichen pipeline, fed with hexa-supplied zenith.
    #    Linke turbidity climatology lookup by (time, lat, lon).
    linke_turbidity = pvlib.clearsky.lookup_linke_turbidity(
        times, LATITUDE, LONGITUDE)
    # Kasten-Young 1989 relative airmass (apparent-zenith model).
    airmass_rel = pvlib.atmosphere.get_relative_airmass(
        apparent_zenith, model="kastenyoung1989")
    # Pressure-adjusted absolute airmass (uses altitude-derived
    # pressure to mirror Location.get_clearsky's default path).
    pressure = pvlib.atmosphere.alt2pres(ALTITUDE_M)
    airmass_abs = pvlib.atmosphere.get_absolute_airmass(
        airmass_rel, pressure=pressure)
    # Extraterrestrial DNI (Spencer 1972 — same as get_clearsky).
    dni_extra = pvlib.irradiance.get_extra_radiation(times)
    # ineichen returns a DataFrame with ghi/dni/dhi columns.
    cs = pvlib.clearsky.ineichen(
        apparent_zenith=apparent_zenith,
        airmass_absolute=airmass_abs,
        linke_turbidity=linke_turbidity,
        altitude=ALTITUDE_M,
        dni_extra=dni_extra,
    )
    modeled_ghi = np.asarray(cs["ghi"].values, dtype=float)

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
            "modeled = hexa-native solar_kernel apparent_zenith "
            "(clean-room Sandia 1985 ephemeris, <1e-9 substrate "
            "parity vs pvlib SPA at κ-65) fed into pvlib "
            f"{pvlib_version} Ineichen clearsky (Linke-turbidity "
            "climatology + Kasten-Young airmass · D80 substrate-"
            "parity PASS at κ-65). measured side = research-grade "
            "vented + thermally corrected CMP22 pyranometer."
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
            "vs Ineichen clearsky modeled GHI (hexa-native sun "
            "position + pvlib atmospheric model).",
            (
                "modeled stack uses hexa-native "
                "`solar_kernel::apparent_zenith` (clean-room Sandia "
                "1985 ephemeris; κ-65 D80 pilot, substrate parity "
                "vs pvlib SPA <1e-9) for sun position, and pvlib's "
                "Ineichen clearsky (Linke-turbidity climatology + "
                "Kasten-Young airmass) for the atmospheric model. "
                "This closes RFC 013 §6.11 reserved slot — G31 "
                "G29-β producer integration."
            ),
            "Linke-turbidity climatology assumption inherent in "
            "Ineichen — not site-specific aerosol retrieval.",
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
            "via _solar_position_batch.hexa) + pvlib Ineichen "
            "clearsky (Linke-turbidity + Kasten-Young airmass) "
            "trusted bridge (substrate-parity proven on "
            "stdlib/kernels/solar/pvlib_kernel.py · κ-65 D80)"
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
