#!/usr/bin/env python3
# scope_poppy.py — `scope + analyze` producer (D67 / κ-35).
#
# ①b DOMAIN ADAPTER (demiurge design.md D72 2-layer STDLIB restructure).
# This file owns ONLY the scope/segmented-mirror domain: the JWST-class
# segment geometry (1.32 m flat-to-flat, 7/18/36 shelf option), the
# 550 nm green-visible band, the detector FOV / pixel scale, and the
# honesty caveats. All wave-optics math (MultiHexagonAperture build,
# Fraunhofer/Fresnel propagation, Strehl / FWHM / encircled-energy
# post) lives in the domain-AGNOSTIC ①a kernel
# `stdlib/kernels/wave_optics/poppy_kernel.py` — this adapter imports
# and calls it. The day a hexa-native wave-optics kernel lands,
# `absorbed` flips in the kernel, not here.
#
# SSOT location: `~/core/hexa-lang/stdlib/scope/scope_poppy.py` (D61 —
# producer scripts live under hexa-lang/stdlib/<domain>/, sibling repo
# from demiurge; cockpit/scripts/*.py is forbidden for NEW producers).
#
# Invoked by Swift's ScopeAnalyzeProducer via:
#   /opt/homebrew/bin/python3.12 ~/core/hexa-lang/stdlib/scope/scope_poppy.py \
#       <output_dir>
#
# What it does (honest scope):
#   1. Builds a *parametric* segmented primary aperture via the ①a
#      wave-optics kernel's `MultiHexagonAperture` wrapper, per
#      `domains/scope.md` §6 shelf option (`분할 수 = 7 / 18 / 36`) —
#      default = 18, matching the JWST reference (1.32 m hex segment;
#      total ≈ 6.5 m collecting diameter). argv[2] picks 7|18|36.
#   2. Propagates a monochromatic point source at λ = 550 nm through
#      the aperture via the kernel and computes:
#        • Strehl proxy (peak vs diffraction-limited-peak estimate)
#        • FWHM in arcsec
#        • Encircled energy at 1, 2, 5 arcsec radii
#        • Aperture diameter / area (m, m²)
#   3. Writes `scope_psf_v1.fits` (the 2-D PSF as a FITS image — the
#      lingua franca for astronomical data) + `scope_psf_v1.meta.json`
#      and prints `SCOPE_POPPY_RESULT <json>` summary line on stderr.
#
# HONESTY (g3 — non-negotiable):
#   • POPPY's diffractive propagation IS the instrument here — the
#     numbers (Strehl, FWHM, encircled energy) are real Fraunhofer/
#     Fresnel calculations on the parametric aperture. But the
#     aperture is *parametric* (n segments × hex geometry), NOT a
#     measured wavefront from a real polished primary. So
#     measurement_gate stays GATE_OPEN.
#   • The Code V / Zemax tolerancing gap (domains/scope.md §4) is
#     orthogonal — POPPY does PSF, not ray-trace tolerancing. We
#     don't pretend this is mission-grade optical-design closure.
#   • `absorbed=true` is NEVER set. Real absorption would require
#     a JWST-class wavefront map (e.g. NIRCam commissioning hash)
#     + Strehl reproduction within ±X% — that's a later phase.

import json
import os
import platform
import sys


# --- Locate the ①a wave-optics kernel. The demiurge `python3 <script>
# <out_dir>` spawn uses an arbitrary cwd, so resolve the kernel path
# relative to THIS file: stdlib/scope/scope_poppy.py ->
# stdlib/kernels/wave_optics/. Same locate-by-__file__ pattern the
# graph, fem and orbital ①b adapters use.
_KERNEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "kernels", "wave_optics"))
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

import poppy_kernel  # noqa: E402  — ①a domain-agnostic wave-optics kernel


# ------------------------------------------------------------------
# DOMAIN data — owned by this ①b adapter, not the kernel.
# ------------------------------------------------------------------
GEOMETRY_ID = "scope_psf_v1"

# Defaults — picked to mirror the JWST 18-segment reference cited in
# `domains/scope.md` §1. Override `segments` via argv[2].
DEFAULT_SEGMENTS = 18
SEGMENT_FLAT_TO_FLAT_M = 1.32          # JWST single-hex flat-to-flat
WAVELENGTH_M = 550.0e-9                # green visible (550 nm)
FOV_ARCSEC = 6.0                       # PSF window full width
PIXSCALE_ARCSEC = 0.020                # ~Nyquist for visible / 6.5 m
OVERSAMPLE = 2                         # POPPY oversampling factor
SEGMENT_GAP_M = 0.007                  # 7 mm inter-segment gap — typical


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: scope_poppy.py <output_dir> [segments=18]\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    try:
        segments = int(argv[2]) if len(argv) >= 3 else DEFAULT_SEGMENTS
    except ValueError:
        segments = DEFAULT_SEGMENTS

    fits_path = os.path.join(output_dir, f"{GEOMETRY_ID}.fits")
    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")

    # The kernel imports poppy/numpy/astropy internally; surface an
    # import failure honestly here (g3 — silent success forbidden).
    try:
        import numpy as np  # noqa: F401
        import poppy  # noqa: F401
        import astropy.units as u  # noqa: F401
    except ImportError as exc:
        sys.stderr.write(f"scope_poppy: missing dependency — {exc}\n"
                         "SCOPE_POPPY_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": f"import: {exc}"},
                                      sort_keys=True)
                         + "\n")
        return 3

    import numpy as np

    built = poppy_kernel.build_multihex_aperture(
        segments, SEGMENT_FLAT_TO_FLAT_M, gap_m=SEGMENT_GAP_M)
    aperture = built["aperture"]
    rings = built["rings"]

    try:
        prop = poppy_kernel.propagate_psf(
            aperture, WAVELENGTH_M, FOV_ARCSEC, PIXSCALE_ARCSEC,
            oversample=OVERSAMPLE)
    except Exception as exc:
        sys.stderr.write(f"scope_poppy: calc_psf failed — {exc}\n")
        sys.stderr.write("SCOPE_POPPY_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": f"calc_psf: {exc}"},
                                      sort_keys=True)
                         + "\n")
        return 4

    psf = prop["psf"]
    psf_hash = prop["psf_sha256_16"]

    try:
        psf.writeto(fits_path, overwrite=True)
    except Exception as exc:
        sys.stderr.write(f"scope_poppy: fits write failed — {exc}\n")
        return 5

    diameter_m = poppy_kernel.aperture_diameter_m(
        aperture, SEGMENT_FLAT_TO_FLAT_M)
    measurements = poppy_kernel.compute_psf_metrics(
        psf, diameter_m, WAVELENGTH_M, PIXSCALE_ARCSEC,
        ee_radii_arcsec=(1.0, 2.0, 5.0))
    version = poppy_kernel.poppy_version()
    area_m2 = float(np.pi * (diameter_m / 2.0) ** 2)

    ok = (measurements["peak_intensity"] is not None
          and measurements["total_intensity"] > 0)

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "psf_sha256_16": psf_hash,
        "poppy_version": version,
        "python_version": platform.python_version(),
        "aperture": {
            "segments_requested": segments,
            "rings": rings,
            "segment_flat_to_flat_m": SEGMENT_FLAT_TO_FLAT_M,
            "effective_diameter_m": diameter_m,
            "effective_area_m2": area_m2,
        },
        "propagation": {
            "wavelength_m": WAVELENGTH_M,
            "fov_arcsec": FOV_ARCSEC,
            "pixscale_arcsec": PIXSCALE_ARCSEC,
            "oversample": OVERSAMPLE,
        },
        "measurements": measurements,
        "artifacts": {
            "fits": f"{GEOMETRY_ID}.fits",
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(f"scope_poppy: wrote {meta_path} (ok={ok}, "
                     f"diameter={diameter_m:.2f} m, "
                     f"fwhm={measurements['fwhm_measured_arcsec']})\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "psf_sha256_16": psf_hash,
        "poppy_version": version,
        "segments": segments,
        "rings": rings,
        "effective_diameter_m": diameter_m,
        "fwhm_measured_arcsec": measurements["fwhm_measured_arcsec"],
        "strehl_proxy": measurements["strehl_proxy"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("SCOPE_POPPY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 6


if __name__ == "__main__":
    sys.exit(main(sys.argv))
