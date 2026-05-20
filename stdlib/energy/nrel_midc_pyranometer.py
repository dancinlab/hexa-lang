# nrel_midc_pyranometer.py — REAL measured-oracle producer
# (κ-68 G29 · RFC 013 §6.11 first cell absorbed=true legitimate flip ·
#  demiurge design.md D109 · supersedes G28b STUB · this is the
#  production path)
#
# Fetches a single day of NREL MIDC pyranometer GHI from the BMS
# (Baseline Measurement System) at the Solar Radiation Research
# Laboratory (SRRL) in Golden CO, computes a pvlib Ineichen clearsky
# modeled GHI, applies a clear-sky filter, and emits an Energy/verify
# record with the `measured_oracle` block populated by the real
# measured-vs-modeled comparison.
#
# When `mean_rel_err <= 0.05` (the D109 PASS criterion) over the
# clear-sky daylight window, the emitted record carries
# `absorbed = true` — this is the κ-68 first cell `absorbed: Bool`
# legitimate flip, driven by an EXTERNAL measured oracle (not a D95
# computed projection from substrate-parity).
#
# HONESTY (g3 — non-negotiable):
#   - The measured side is REAL NREL MIDC pyranometer data (Global
#     CMP22 (vent/cor) channel — research-grade, vented + thermally
#     corrected). No synthetic numbers.
#   - The modeled side is pvlib's Ineichen clearsky model, which
#     depends on Linke-turbidity climatology and is itself an
#     atmospheric idealization. Substrate-parity for the bridge stack
#     (pvlib clearsky + transposition) is already proven on
#     `stdlib/kernels/solar/pvlib_kernel.py` (κ-65 D80 pilot — solar
#     21/21 PASS at rel_err <= 1e-13). This producer treats that
#     bridge as TRUSTED per design.md D109.
#   - The hexa-native scope per D109 is `solar_position_kernel` (sun
#     position only). This producer does NOT yet call the hexa
#     interpreter — sun position is computed by pvlib internally and
#     the D80 g_hexa_only port to the hexa-native sun-position kernel
#     is a separate G29-β follow-on (the parity-of-implementation
#     between pvlib's solar position and `solar_kernel.hexa` was
#     already established at κ-65; this producer reuses that result).
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


def _compute_modeled(date, n_minutes):
    """pvlib Ineichen clearsky → modeled GHI for the day."""
    loc = pvlib.location.Location(
        latitude=LATITUDE, longitude=LONGITUDE,
        altitude=ALTITUDE_M, tz=TZ)
    times = pd.date_range(
        start=f"{date} 00:00:00", periods=n_minutes,
        freq="1min", tz=TZ)
    solpos = loc.get_solarposition(times)
    clearsky = loc.get_clearsky(times, model="ineichen")
    return pd.DataFrame({
        "pvlib_zenith": solpos["zenith"].values,
        "modeled_ghi": clearsky["ghi"].values,
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
            f"modeled = pvlib {pvlib_version} Ineichen clearsky "
            "(Linke-turbidity climatology · D80 substrate-parity "
            "PASS at κ-65). measured side = research-grade vented + "
            "thermally corrected CMP22 pyranometer."
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
            "vs pvlib Ineichen clearsky modeled GHI.",
            (
                "modeled stack uses pvlib clearsky (Ineichen) + sun "
                "position; the latter has D80 substrate-parity vs "
                "hexa-native `solar_position_kernel` (κ-65 21/21 "
                "PASS at rel_err <= 1e-13) — the hexa-native call "
                "site is a G29-β follow-on (substrate-parity already "
                "proven, runtime port is the next axis)."
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
            "pvlib clearsky/transposition trusted bridge (substrate-"
            "parity proven on stdlib/kernels/solar/pvlib_kernel.py)"
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
