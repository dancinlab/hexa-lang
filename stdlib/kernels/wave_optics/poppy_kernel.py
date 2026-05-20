# poppy_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic wave-optics computation kernel. This is the FOURTH
# kernel extracted under the D72 2-layer STDLIB restructure (after
# kernels/graph/, kernels/fem/ and kernels/orbital/): producers in
# `stdlib/<domain>/` that compute diffractive PSFs (scope+analyze
# today; any future photonics domain) call into this single module
# instead of each re-implementing the POPPY wrapping.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No JWST 18-segment
#                shelf, no 1.32 m flat-to-flat default, no 550 nm
#                green-visible band — only "given an aperture + a
#                wavelength + a detector spec, propagate the wavefront
#                (Fraunhofer/Fresnel) and reduce it to PSF facts".
#   ①b adapter — `stdlib/scope/scope_poppy.py` (and any future
#                photonics-domain adapter). They own the segment
#                geometry, the band, the FOV shelf and the honesty
#                caveats, and call this kernel for the wave-optics
#                math.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * Every value computed here IS a real Fraunhofer/Fresnel
#     diffraction calculation on the supplied aperture — physically
#     correct given the inputs (deterministic ndarray IEEE-754). It is
#     NOT a measurement of any real polished primary. Whether the
#     aperture is parametric or a measured wavefront map is a domain
#     question — the honesty gate (`measurement_gate`, `absorbed`,
#     `scope_caveats`) lives in the ①b adapter, NOT here.
#   * absorbed = false ALWAYS at the record layer — POPPY is an
#     EXTERNAL Python library (pip install, STScI/BSD), not absorbed
#     into hexa-lang. The day a hexa-native wave-optics kernel
#     re-propagates these wavefronts with a numerically-equivalent FFT
#     method, absorbed flips — and it flips HERE (one kernel) rather
#     than in N domain adapters. That is the entire point of the
#     2-layer restructure (N×M -> N+M).
#   * Strehl here is a PROXY (peak / diffraction-limited-peak estimate),
#     NOT a Code V / Zemax strict Strehl from a second reference
#     propagation. The ①b adapter must surface that caveat.
#   * Import failure / propagation failure is raised, not swallowed —
#     silent success is forbidden. The caller reports it verbatim.

import hashlib
import math
from typing import Any


# ------------------------------------------------------------------
# Version probe — let the ①b adapter pin the library in its record
# provenance ("poppy@<v>"). Returns 'unknown' if POPPY cannot be
# imported; the caller decides whether that is a hard gap (it is, for
# wave-optics producers).
# ------------------------------------------------------------------
def poppy_version() -> str:
    """Probe the installed POPPY version string."""
    try:
        import poppy
        return str(poppy.__version__)
    except Exception:
        return "unknown"


# ------------------------------------------------------------------
# Segmented-aperture construction via POPPY's MultiHexagonAperture.
# Domain-agnostic: the caller supplies the requested segment count and
# the per-segment flat-to-flat size; the kernel maps the count to the
# nearest supported ring config and builds the aperture.
# ------------------------------------------------------------------
def build_multihex_aperture(segments: int,
                             segment_flat_to_flat_m: float,
                             gap_m: float = 0.007,
                             name: str = "segmented_primary") -> dict:
    """Construct a parametric `MultiHexagonAperture`.

    POPPY's `rings` arg counts rings AROUND the centre: ring 1 = 7
    hexes, ring 2 = 19, ring 3 = 37. The requested `segments` is
    rounded to the nearest supported ring config (<=7 -> 1, <=19 -> 2,
    else 3). Domain-agnostic — the caller decides what the aperture
    represents (JWST-class scope, a photonics test bench).

    Returns { "aperture": <poppy.MultiHexagonAperture>, "rings": int }."""
    import poppy

    if segments <= 7:
        rings = 1     # 7 hexes
    elif segments <= 19:
        rings = 2     # 19 hexes
    else:
        rings = 3     # 37 hexes
    ap = poppy.MultiHexagonAperture(
        name=name,
        rings=rings,
        side=segment_flat_to_flat_m / 2.0,
        gap=gap_m)
    return {"aperture": ap, "rings": rings}


def aperture_diameter_m(ap: Any,
                        fallback_flat_to_flat_m: float) -> float:
    """Total tip-to-tip collecting diameter for a MultiHexagonAperture.

    MultiHexagonAperture.flattoflat is the *segment* flat-to-flat; the
    effective collecting diameter for an r-ring hex lattice is
    approximately (2r + 1) × flat_to_flat. POPPY may store flattoflat
    as an astropy Quantity or a plain float depending on version —
    both are handled. `fallback_flat_to_flat_m` is used when the
    attributes are absent. Domain-agnostic geometry post-processing.

    NOTE (geometry, 2026-05-20 hex-pack-area fix): the returned value
    is the *bounding-disk diameter* across the flat axis of the hex
    lattice — i.e., a circumscribed-disk proxy convenient for the
    diffraction-limit FWHM (λ/D). It is NOT the hex-packed collecting
    area's equivalent diameter. For collecting-area work call
    `hex_collecting_area_m2` instead."""
    if hasattr(ap, "flattoflat") and hasattr(ap, "rings"):
        ftf_attr = ap.flattoflat
        if hasattr(ftf_attr, "to"):
            import astropy.units as u
            ftf = float(ftf_attr.to(u.m).value)
        else:
            ftf = float(ftf_attr)
        n = int(ap.rings)
    else:
        ftf = float(fallback_flat_to_flat_m)
        n = 1
    return (2 * n + 1) * ftf


def hex_ring_segment_count(rings: int) -> int:
    """Total segment count for an r-ring POPPY MultiHexagonAperture
    (central hex + all rings around it). Closed-form:

        N(0) = 1
        N(r) = 1 + 6 · r·(r+1)/2 = 1 + 3·r·(r+1)
             = 7   for r=1
             = 19  for r=2
             = 37  for r=3
             = 61  for r=4

    Domain-agnostic. Use this instead of the (7, 18, 36) labels the
    `openmdao_sizing.py` ①b adapter historically carried, which were
    off-by-one in the outer ring (see
    `~/core/demiurge/inbox/notes/parity_attempt_scope_synth_2026-05-20.md`
    root-cause §2 for the trail).
    """
    r = int(rings)
    if r < 0:
        raise ValueError(f"hex_ring_segment_count: rings must be ≥ 0 (got {r})")
    return 1 + 3 * r * (r + 1)


def hex_collecting_area_m2(ap: Any,
                            fallback_flat_to_flat_m: float) -> float:
    """Hex-packed collecting area (sum of segment areas) for a POPPY
    MultiHexagonAperture, in m².

    Math: each regular hexagon with edge length `a` has area
        A_hex = (3·√3 / 2) · a²
    equivalently, with flat-to-flat width `ftf = √3 · a`,
        A_hex = (√3 / 2) · ftf²
    The total collecting area is N · A_hex, where N is the actual
    POPPY ring population (1 + 3·r·(r+1)).

    Reads POPPY's actual `side` (= edge length) attribute so the
    returned area reflects exactly the geometry that was propagated —
    NOT a substrate-side approximation. `fallback_flat_to_flat_m` is
    used only when the aperture lacks the POPPY attrs.

    This is the right area to use in mass-model / collecting-power
    objectives. The disk-bounded `aperture_diameter_m` overstates the
    flat-axis extent (good for FWHM) but understates the corner-axis
    extent and is not the geometric area — see parity-attempt note
    referenced above for measured 7–13 % discrepancies vs disk."""
    if hasattr(ap, "side") and hasattr(ap, "rings"):
        side_attr = ap.side
        if hasattr(side_attr, "to"):
            import astropy.units as u
            side = float(side_attr.to(u.m).value)
        else:
            side = float(side_attr)
        n_segments = hex_ring_segment_count(int(ap.rings))
    else:
        # Fallback: assume the supplied flat-to-flat IS the true
        # segment flat-to-flat (NOT the doubled-edge-length convention
        # the current ①b adapter passes through).
        ftf = float(fallback_flat_to_flat_m)
        side = ftf / math.sqrt(3.0)
        n_segments = 7
    return n_segments * (3.0 * math.sqrt(3.0) / 2.0) * side * side


# ------------------------------------------------------------------
# Fraunhofer/Fresnel wavefront propagation.
#
# Given an aperture, a wavelength and a detector spec, the kernel
# builds a POPPY OpticalSystem, propagates a monochromatic point
# source and returns the PSF HDU list plus a content hash.
#
# Domain-agnostic — the caller decides the wavelength band, the FOV
# and the oversampling factor.
# ------------------------------------------------------------------
def propagate_psf(aperture: Any,
                  wavelength_m: float,
                  fov_arcsec: float,
                  pixscale_arcsec: float,
                  oversample: int = 2,
                  name: str = "segmented_primary_psf") -> dict:
    """Propagate a monochromatic point source through `aperture` and
    compute the diffractive PSF.

    Arguments
      aperture        : a POPPY optic to add as the pupil.
      wavelength_m    : monochromatic wavelength (metres).
      fov_arcsec      : detector field-of-view full width (arcsec).
      pixscale_arcsec : detector pixel scale (arcsec / pixel).
      oversample      : POPPY oversampling factor (default 2).

    Returns { "psf": <fits HDUList>, "psf_sha256_16": str } — the PSF
    HDU list (writeable to FITS) and a SHA-256 (16 hex) hash of the
    PSF data array (drift sentinel). Deterministic Fraunhofer/Fresnel
    diffraction output, NOT a measurement of any real instrument."""
    import numpy as np
    import poppy
    import astropy.units as u

    osys = poppy.OpticalSystem(name=name, oversample=oversample)
    osys.add_pupil(aperture)
    osys.add_detector(pixelscale=pixscale_arcsec * u.arcsec / u.pixel,
                      fov_arcsec=fov_arcsec * u.arcsec)
    psf = osys.calc_psf(wavelength=wavelength_m * u.m,
                        display_intermediates=False)

    img_bytes = np.asarray(psf[0].data, dtype=np.float64).tobytes()
    psf_hash = hashlib.sha256(img_bytes).hexdigest()[:16]
    return {"psf": psf, "psf_sha256_16": psf_hash}


# ------------------------------------------------------------------
# PSF metric extraction: Strehl proxy, FWHM, encircled energy.
#
# Given a propagated PSF HDU list and the aperture diameter, the
# kernel pulls the headline figures. Domain-agnostic post-processing.
# ------------------------------------------------------------------
def compute_psf_metrics(psf_hdulist: Any,
                        aperture_diameter_m: float,
                        wavelength_m: float,
                        default_pixscale_arcsec: float,
                        ee_radii_arcsec=(1.0, 2.0, 5.0)) -> dict:
    """Pull Strehl proxy, FWHM and encircled energy from a POPPY PSF.

    Arguments
      psf_hdulist             : the HDU list from `propagate_psf`.
      aperture_diameter_m     : effective collecting diameter (metres).
      wavelength_m            : the propagation wavelength (metres).
      default_pixscale_arcsec : fallback pixel scale if the FITS header
                                has no PIXELSCL key.
      ee_radii_arcsec         : radii (arcsec) at which to sample the
                                encircled-energy curve.

    Returns { peak_intensity, total_intensity, strehl_proxy,
    fwhm_diffraction_limit_arcsec, fwhm_measured_arcsec,
    pixscale_arcsec, encircled_energy, image_shape }.

    NOTE (g3): `strehl_proxy` is peak / (total / (1.13 · FWHM_pix²)) —
    a conservative proxy that avoids a second reference propagation. It
    is NOT a strict Code V / Zemax Strehl; the ~2 % discrepancy is a
    domain caveat the ①b adapter must surface. NaN/Inf encircled-energy
    and FWHM values (radius beyond detector FOV) are converted to None
    so the JSON stays decoder-clean."""
    import numpy as np
    import poppy

    hdu = psf_hdulist[0]
    img = np.asarray(hdu.data, dtype=np.float64)
    pixscale = float(hdu.header.get("PIXELSCL", default_pixscale_arcsec))

    peak = float(np.max(img))
    total = float(np.sum(img))

    # Airy diffraction-limited FWHM: 1.22 λ/D in radians -> arcsec.
    fwhm_arcsec = 1.22 * (wavelength_m / aperture_diameter_m) \
        * (180.0 / math.pi) * 3600.0
    fwhm_pix = fwhm_arcsec / pixscale
    if fwhm_pix > 0 and total > 0:
        strehl_proxy = peak / (total / (1.13 * fwhm_pix * fwhm_pix))
    else:
        strehl_proxy = None

    encircled = {}
    for r in ee_radii_arcsec:
        try:
            ee_fn = poppy.measure_ee(psf_hdulist, ext=0,
                                     normalize="total")
            v = float(ee_fn(r))
            encircled[f"r_{int(r)}_arcsec"] = (
                None if np.isnan(v) or np.isinf(v) else v)
        except Exception:
            encircled[f"r_{int(r)}_arcsec"] = None

    try:
        fwhm_meas = float(poppy.measure_fwhm(psf_hdulist, ext=0))
        if np.isnan(fwhm_meas) or np.isinf(fwhm_meas):
            fwhm_meas = None
    except Exception:
        fwhm_meas = None

    return {
        "peak_intensity": peak,
        "total_intensity": total,
        "strehl_proxy": strehl_proxy,
        "fwhm_diffraction_limit_arcsec": fwhm_arcsec,
        "fwhm_measured_arcsec": fwhm_meas,
        "pixscale_arcsec": pixscale,
        "encircled_energy": encircled,
        "image_shape": list(img.shape),
    }
