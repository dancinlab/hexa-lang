# sgp4_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic orbital-mechanics computation kernel. This is the
# THIRD kernel extracted under the D72 2-layer STDLIB restructure
# (after kernels/graph/networkx_kernel.py and kernels/fem/
# skfem_kernel.py): producers in `stdlib/<domain>/` that propagate
# satellite orbits (space+analyze today; any future satellite domain)
# call into this single module instead of each re-implementing the
# Skyfield + SGP4 wrapping.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No ISS, no HST, no
#                Seoul observer, no 24-hour shelf window — only "given
#                a TLE + an observer + a sample window, propagate the
#                orbit and reduce it to topocentric track facts".
#   ①b adapter — `stdlib/space/skyfield_sgp4.py` (and any future
#                satellite-domain adapter). They own the bundled TLE
#                set, the observer site, the window shelf options and
#                the honesty caveats, and call this kernel for the
#                orbital-mechanics math.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * Every value computed here IS a real SGP4 propagation result —
#     SGP4 is the NORAD-standard analytic propagator and Skyfield
#     binds the C reference implementation (Vallado 2006: ~1 km
#     positional accuracy at epoch). It is NOT a model prediction.
#   * BUT — SGP4 accuracy DECAYS with TLE age (~1 km/day position
#     drift; ~3 km/week; loses usefulness past ~2 weeks). The kernel
#     surfaces `tle_age_days` for every TLE so the ①b adapter can
#     gate on it; the honesty gate (measurement_gate, scope_caveats)
#     lives in the adapter, NOT here.
#   * absorbed = false ALWAYS at the record layer — Skyfield and sgp4
#     are EXTERNAL Python libraries, not absorbed into hexa-lang. The
#     day a hexa-native orbital kernel re-propagates these orbits with
#     a numerically-equivalent method, absorbed flips — and it flips
#     HERE (one kernel) rather than in N domain adapters. That is the
#     entire point of the 2-layer restructure (N×M -> N+M).
#   * Import failure / propagation failure is raised, not swallowed —
#     silent success is forbidden. The caller reports it verbatim.

import hashlib
from datetime import datetime, timedelta, timezone
from typing import Any


# ------------------------------------------------------------------
# Version probes — let the ①b adapter pin the libraries in its record
# provenance ("skyfield@<v> + sgp4@<v>"). Return 'unknown' if the
# library cannot be imported; the caller decides whether that is a
# hard gap (it is, for orbital producers).
# ------------------------------------------------------------------
def skyfield_version() -> str:
    """Probe the installed skyfield version string."""
    try:
        import skyfield
        v = getattr(skyfield, "VERSION", None)
        return ".".join(str(x) for x in v) if v else "unknown"
    except Exception:
        return "unknown"


def sgp4_version() -> str:
    """Probe the installed sgp4 version."""
    try:
        import sgp4
        return str(getattr(sgp4, "__version__", "unknown"))
    except Exception:
        return "unknown"


def versions() -> dict:
    """Both propagator-stack versions in one dict — convenience for the
    adapter's provenance string."""
    return {"skyfield": skyfield_version(), "sgp4": sgp4_version()}


# ------------------------------------------------------------------
# TLE text utilities. Domain-agnostic — given any NORAD TLE the kernel
# parses the epoch and hashes the input text.
# ------------------------------------------------------------------
def tle_epoch_utc(line1: str) -> datetime:
    """Parse the TLE epoch (cols 19-32 of line 1) -> tz-aware UTC
    datetime. Format: YYDDD.dddddddd (YY = 2-digit year, DDD = day of
    year, Jan 1 = DOY 1.0). Domain-agnostic — works for any TLE."""
    raw = line1[18:32]
    yy = int(raw[0:2])
    year = 2000 + yy if yy < 57 else 1900 + yy
    doy = float(raw[2:])
    day_int = int(doy)
    frac = doy - day_int
    base = datetime(year, 1, 1, tzinfo=timezone.utc)
    return base + timedelta(days=day_int - 1, seconds=frac * 86400.0)


def tle_text_hash(tles: list) -> str:
    """SHA-256 (first 16 hex chars) of the concatenated TLE text — pins
    the producer input. Each entry must carry `name`, `line1`, `line2`.
    Domain-agnostic input-provenance hash."""
    text = "\n".join(
        f"{e['name']}\n{e['line1']}\n{e['line2']}" for e in tles
    )
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


# ------------------------------------------------------------------
# SGP4 propagation + topocentric reduction.
#
# Given one satellite's TLE pair, a ground observer (lat/lon/elev) and
# a sample window, the kernel propagates the orbit and computes per
# sample the altitude/azimuth/range from the observer and the sub-
# satellite ground point, then aggregates the visibility statistics.
#
# Domain-agnostic — the caller decides which satellites, which observer
# site, which window length and which horizon cutoff.
# ------------------------------------------------------------------
def propagate_track(line1: str,
                    line2: str,
                    name: str,
                    observer_lat_deg: float,
                    observer_lon_deg: float,
                    observer_elev_m: float,
                    t0_utc: datetime,
                    sample_count: int,
                    step_s: int,
                    visibility_alt_deg: float = 10.0) -> dict:
    """Propagate one satellite over `sample_count` samples at `step_s`
    spacing from `t0_utc`, reducing to the topocentric frame of a fixed
    ground observer.

    Arguments
      line1, line2        : the NORAD TLE pair.
      name                : satellite display name (passed to Skyfield).
      observer_lat/lon_deg: ground-station geodetic coordinates.
      observer_elev_m     : ground-station elevation (metres).
      t0_utc              : tz-aware UTC start of the sample window.
      sample_count        : number of samples.
      step_s              : sample spacing in seconds.
      visibility_alt_deg  : horizon cutoff — a sample counts as visible
                            iff alt_deg exceeds this (default 10°).

    Returns { "rows": [...], "aggregates": {...} } — `rows` is a list
    of per-sample dicts suitable for NDJSON, `aggregates` is the per-
    satellite summary (sample/visible counts, ratio, max/mean altitude
    over visible samples, longest contiguous pass in minutes, visible-
    window count). All values are deterministic SGP4 outputs, NOT model
    predictions."""
    from skyfield.api import EarthSatellite, load, wgs84

    ts = load.timescale()
    observer = wgs84.latlon(observer_lat_deg, observer_lon_deg,
                            observer_elev_m)
    sat = EarthSatellite(line1, line2, name, ts)

    rows = []
    visible_window_lengths = []
    current_window = 0
    visible_count = 0
    sum_alt_visible = 0.0
    max_alt = -90.0

    for i in range(sample_count):
        t = ts.from_datetime(t0_utc + timedelta(seconds=i * step_s))
        difference = sat - observer
        topocentric = difference.at(t)
        alt, az, dist = topocentric.altaz()
        alt_deg = alt.degrees
        az_deg = az.degrees
        dist_km = dist.km

        # Sub-satellite ground point (geodetic lat/lon/elev).
        geocentric = sat.at(t)
        subpoint = geocentric.subpoint()
        sub_lat = subpoint.latitude.degrees
        sub_lon = subpoint.longitude.degrees
        sub_elev_km = subpoint.elevation.km

        visible = bool(alt_deg > visibility_alt_deg)
        if visible:
            visible_count += 1
            sum_alt_visible += alt_deg
            current_window += 1
            if alt_deg > max_alt:
                max_alt = alt_deg
        else:
            if current_window > 0:
                visible_window_lengths.append(current_window)
                current_window = 0

        rows.append({
            "i": i,
            "t_utc": (t0_utc + timedelta(seconds=i * step_s)).isoformat()
                .replace("+00:00", "Z"),
            "alt_deg": round(float(alt_deg), 4),
            "az_deg": round(float(az_deg), 4),
            "range_km": round(float(dist_km), 3),
            "sub_lat_deg": round(float(sub_lat), 4),
            "sub_lon_deg": round(float(sub_lon), 4),
            "sub_elev_km": round(float(sub_elev_km), 3),
            "visible": visible,
        })

    if current_window > 0:
        visible_window_lengths.append(current_window)

    visibility_ratio = (visible_count / sample_count) if sample_count else 0.0
    mean_alt_visible = (sum_alt_visible / visible_count) if visible_count else None
    max_pass_minutes = (max(visible_window_lengths) * step_s / 60.0
                        if visible_window_lengths else 0.0)
    if max_alt < -89.0:
        # No visible sample — max_alt was never set; surface as None.
        max_alt_value = None
    else:
        max_alt_value = round(float(max_alt), 4)

    aggregates = {
        "sample_count": int(sample_count),
        "visible_count": int(visible_count),
        "visibility_ratio": round(float(visibility_ratio), 4),
        "max_alt_deg": max_alt_value,
        "mean_alt_deg_visible": (round(float(mean_alt_visible), 4)
                                 if mean_alt_visible is not None else None),
        "max_pass_minutes": round(float(max_pass_minutes), 2),
        "visible_window_count": int(len(visible_window_lengths)),
    }
    return {"rows": rows, "aggregates": aggregates}
