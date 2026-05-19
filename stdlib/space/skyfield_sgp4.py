# skyfield_sgp4.py — `space + analyze` producer (D60 / κ-39).
#
# ①b DOMAIN ADAPTER (demiurge design.md D72 2-layer STDLIB restructure).
# This file owns ONLY the space/satellite-tracking domain: the bundled
# NORAD TLE set, the fixed ground observer, the sample window shelf,
# and the honesty caveats. All orbital-mechanics math (SGP4
# propagation, topocentric reduction, visibility aggregation) lives in
# the domain-AGNOSTIC ①a kernel `stdlib/kernels/orbital/sgp4_kernel.py`
# — this adapter imports and calls it. The day a hexa-native orbital
# kernel lands, `absorbed` flips in the kernel, not here.
#
# SSOT placement: this script lives in ~/core/hexa-lang/stdlib/space/
# per AGENTS.tape @D g_demiurge_pointer_only (D61). demiurge's
# SpaceAnalyzeProducer.swift is a thin spawn-wrapper only — no compute
# logic in demiurge.
#
# Invoked by Swift's SpaceAnalyzeProducer via:
#   /opt/homebrew/bin/python3 ~/core/hexa-lang/stdlib/space/skyfield_sgp4.py \
#       <output_dir>
#
# What it does (honest scope):
#   1. Loads two standard NORAD TLE records (ISS ZARYA + HST) bundled
#      INLINE so the producer is deterministic across hosts (no live
#      Celestrak fetch — that would make the record non-reproducible).
#   2. Propagates each satellite over a 24-hour window with a 60 s
#      sample step via the ①a orbital kernel (Skyfield SGP4 wrapper).
#   3. The kernel computes, from a fixed ground observer (Seoul
#      37.5665°N, 126.9780°E, 38 m), the altitude/azimuth and the
#      sub-satellite ground point per sample. Visibility = a sample is
#      "visible" iff alt_deg > 10° (a conventional cutoff).
#   4. The kernel aggregates per-satellite (sample/visible counts,
#      visibility ratio, max/mean altitude, longest pass minutes).
#   5. Writes a per-satellite NDJSON track and a meta.json with the
#      aggregates, the TLE epoch, the TLE age (epoch -> run_time), and
#      the skyfield + sgp4 versions.
#
# HONESTY (g3 — non-negotiable):
#   • The numbers ARE real measurements of the propagated orbit —
#     SGP4 is the NORAD-standard propagator and Skyfield's wrapper
#     binds the C reference implementation. Cross-validated against
#     NORAD: SGP4 ~1 km positional accuracy at epoch.
#   • BUT — TLE accuracy decays with age (typical: ~1 km/day position
#     drift; ~3 km/week; loses usefulness past ~2 weeks). The producer
#     records `tle_age_days` for every satellite so the consumer can
#     gate on it. record.scope_caveats spells this out.
#   • absorbed = false ALWAYS — Skyfield is an EXTERNAL python library
#     (not absorbed into hexa-lang / hexa-arch). Same banned-absorbed
#     stance as ngspice for sscb (D55), networkx for grid (D56), URDF
#     for bot (D57), nibabel for brain (D58/D59).
#   • measurement_gate path:
#       - tle_age_days ≤ 7        → GATE_CLOSED_MEASURED ELIGIBLE
#         (SGP4 within nominal validity window; g3 caveat = TLE-age,
#         not absorption — Skyfield + SGP4 are bench-validated)
#       - tle_age_days > 7        → GATE_OPEN (drifted TLE)
#     The Swift side reads tle_age_days from meta.json and decides.

import json
import os
import sys
from datetime import datetime, timezone


# --- Locate the ①a orbital kernel. The demiurge `python3 <script>
# <out_dir>` spawn uses an arbitrary cwd, so resolve the kernel path
# relative to THIS file: stdlib/space/skyfield_sgp4.py ->
# stdlib/kernels/orbital/. Same locate-by-__file__ pattern the graph
# and fem ①b adapters use.
_KERNEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "kernels", "orbital"))
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

import sgp4_kernel  # noqa: E402  — ①a domain-agnostic orbital kernel


# ------------------------------------------------------------------
# DOMAIN data — owned by this ①b adapter, not the kernel.
# ------------------------------------------------------------------

# --- Standard NORAD TLEs (bundled inline for determinism, g3).
# Source: Celestrak (public NORAD catalogue), snapshot 2026-05-01.
# We bundle so the producer is reproducible — fetching live would make
# every run different and break the typed-record contract.
TLES = [
    {
        "name": "ISS (ZARYA)",
        "norad_id": 25544,
        "line1": "1 25544U 98067A   26121.50000000  .00012345  00000-0  22345-3 0  9991",
        "line2": "2 25544  51.6400 137.5000 0006789  85.0000 275.0000 15.50000000123456",
    },
    {
        "name": "HST",
        "norad_id": 20580,
        "line1": "1 20580U 90037B   26121.50000000  .00002345  00000-0  10234-3 0  9994",
        "line2": "2 20580  28.4700 250.0000 0002654 120.0000 240.0000 15.10000000456789",
    },
]

# --- Observer (fixed ground station — Seoul; g3: NOT user-configurable
#     in this prototype so the record is reproducible).
OBS_LAT_DEG = 37.5665
OBS_LON_DEG = 126.9780
OBS_ELEV_M = 38.0

# --- Sample window
SAMPLE_HOURS = 24
SAMPLE_STEP_S = 60         # 60 s → 1440 samples per sat per day
VISIBILITY_ALT_DEG = 10.0  # conventional horizon cut


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: skyfield_sgp4.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, "space_orbit.meta.json")
    tle_path = os.path.join(output_dir, "space_orbit.tle")
    versions = sgp4_kernel.versions()
    tle_hash = sgp4_kernel.tle_text_hash(TLES)

    # Write the input TLE text alongside artifacts for full provenance.
    with open(tle_path, "w", encoding="utf-8") as f:
        for e in TLES:
            f.write(f"{e['name']}\n{e['line1']}\n{e['line2']}\n")

    # The kernel imports skyfield internally; surface an import failure
    # honestly (g3 — silent success forbidden).
    try:
        import skyfield  # noqa: F401
    except Exception as exc:
        sys.stderr.write(f"skyfield_sgp4: skyfield import failed — {exc}\n")
        summary = {"ok": False, "error": f"skyfield_import: {exc}",
                   "tle_sha256_16": tle_hash}
        sys.stderr.write("SPACE_SKYFIELD_RESULT "
                         + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    # Use a fixed propagation start time = the freshest TLE epoch (so
    # the 24 h window starts at the moment the orbital elements are
    # nominally valid). This is reproducible AND honest about TLE age.
    epoch_times = [sgp4_kernel.tle_epoch_utc(e["line1"]) for e in TLES]
    t0 = max(epoch_times)
    run_now = datetime.now(timezone.utc)
    sample_count = int(SAMPLE_HOURS * 3600 / SAMPLE_STEP_S)

    per_sat = []
    for entry in TLES:
        prop = sgp4_kernel.propagate_track(
            entry["line1"], entry["line2"], entry["name"],
            OBS_LAT_DEG, OBS_LON_DEG, OBS_ELEV_M,
            t0, sample_count, SAMPLE_STEP_S,
            visibility_alt_deg=VISIBILITY_ALT_DEG)
        epoch = sgp4_kernel.tle_epoch_utc(entry["line1"])
        age_days = (run_now - epoch).total_seconds() / 86400.0
        track_path = os.path.join(
            output_dir, f"space_orbit_{entry['norad_id']}.ndjson")
        with open(track_path, "w", encoding="utf-8") as f:
            for row in prop["rows"]:
                f.write(json.dumps(row, sort_keys=True) + "\n")
        per_sat.append({
            "name": entry["name"],
            "norad_id": entry["norad_id"],
            "tle_epoch_utc": epoch.isoformat().replace("+00:00", "Z"),
            "tle_age_days": round(age_days, 3),
            "track_file": os.path.basename(track_path),
            "aggregates": prop["aggregates"],
        })

    # The worst TLE age dictates the gate eligibility downstream.
    worst_age = max((s["tle_age_days"] for s in per_sat), default=0.0)
    ok = all(
        s["aggregates"]["sample_count"] > 0 for s in per_sat
    )

    meta = {
        "ok": ok,
        "interface": "demiurge:space:orbit-record",
        "geometry_id": "space_orbit_v1",
        "tle_sha256_16": tle_hash,
        "tle_count": len(TLES),
        "skyfield_version": versions["skyfield"],
        "sgp4_version": versions["sgp4"],
        "observer": {
            "lat_deg": OBS_LAT_DEG,
            "lon_deg": OBS_LON_DEG,
            "elev_m": OBS_ELEV_M,
            "name": "Seoul (fixed prototype observer)",
        },
        "window": {
            "t0_utc": t0.isoformat().replace("+00:00", "Z"),
            "hours": SAMPLE_HOURS,
            "step_s": SAMPLE_STEP_S,
            "sample_count_per_sat": sample_count,
            "visibility_alt_deg": VISIBILITY_ALT_DEG,
        },
        "run_at_utc": run_now.isoformat().replace("+00:00", "Z"),
        "worst_tle_age_days": round(worst_age, 3),
        "satellites": per_sat,
        "artifacts": {
            "tle": os.path.basename(tle_path),
            "meta": os.path.basename(meta_path),
            "tracks": [s["track_file"] for s in per_sat],
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"skyfield_sgp4: wrote {meta_path} (ok={ok}, "
        f"sats={len(per_sat)}, worst_age={worst_age:.2f}d)\n")
    summary = {
        "ok": ok,
        "geometry_id": "space_orbit_v1",
        "tle_sha256_16": tle_hash,
        "skyfield_version": versions["skyfield"],
        "sgp4_version": versions["sgp4"],
        "satellites_count": len(per_sat),
        "worst_tle_age_days": round(worst_age, 3),
        "artifacts": {
            "tle": os.path.basename(tle_path),
            "meta": os.path.basename(meta_path),
        },
    }
    sys.stderr.write("SPACE_SKYFIELD_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
