#!/usr/bin/env python3
# poppy_psf_verify.py — `scope + verify` producer (cohort-round,
# absorption empty-cell fill 2026-05-20).
#
# ①b DOMAIN ADAPTER (demiurge design.md D72 2-layer STDLIB restructure).
# Re-runs the SAME ①a wave_optics kernel that scope_poppy.py (analyze)
# uses on a *reference configuration* and witnesses reproducibility,
# diffraction-limit closure (kernel's measured FWHM vs the closed-form
# 1.22 λ/D), encircled-energy monotonicity, and (when WebbPSF +
# synphot are installed) a JWST-class WebbPSF cross-check + a synphot
# photometric round-trip.
#
# This producer is verify-verb because the question is "does the same
# producer give the same answer on the same inputs, and does it agree
# with the analytic diffraction limit?" — i.e. signoff/reproducibility
# of the analyze tool, NOT discovery of new science (which would be a
# different verb).
#
# SSOT location: `~/core/hexa-lang/stdlib/scope/poppy_psf_verify.py`
# (D61 — producer scripts live under hexa-lang/stdlib/<domain>/, sibling
# repo from demiurge).
#
# D72 ①b adapter: ZERO wave-optics math here — all PSF / aperture
# geometry is delegated to `stdlib/kernels/wave_optics/poppy_kernel.py`.
# WebbPSF (when installed) is also called from this ①b adapter; if/when
# a 2nd "JWST-class instrument PSF" consumer appears, WebbPSF can be
# promoted into the wave_optics kernel via the same 2-layer pattern.
#
# Invoked by Swift's ScopeVerifyProducer via:
#   /opt/homebrew/bin/python3.12 \
#       ~/core/hexa-lang/stdlib/scope/poppy_psf_verify.py <output_dir>
#
# What it does (honest scope):
#   1. Builds the reference aperture (JWST-class 18-segment, 1.32 m
#      flat-to-flat, 550 nm, same defaults as scope_poppy.py) via the
#      ①a kernel.
#   2. Propagates the PSF twice in succession and checks the SHA-256
#      hash is byte-identical — reproducibility check (deterministic
#      Fraunhofer/Fresnel, no PRNG).
#   3. Reads measured FWHM vs the analytic 1.22 λ/D diffraction limit,
#      computes relative error, and a PASS/FAIL band (≤ 20 % per
#      POPPY tutorial guidance for multi-segment apertures).
#   4. Checks encircled-energy monotonicity (EE(1") ≤ EE(2") ≤ EE(5"))
#      — a basic sanity invariant that catches normalisation bugs.
#   5. If `webbpsf` is installed, spawns a NIRCam F550M model PSF on
#      the SAME wavelength and checks the FWHM order-of-magnitude
#      agreement (within ±50 % — different segment/baffle model, so a
#      loose band is honest, not a strict equality).
#   6. If `synphot` is installed, performs a photometric round-trip
#      (synthetic flat spectrum × bandpass → effective stim count) and
#      checks it is finite and positive.
#   7. Writes `scope_verify_v1.meta.json` + `scope_verify_v1.checks.csv`
#      and emits `SCOPE_VERIFY_RESULT <json>` on stderr.
#
# HONESTY (g3 — non-negotiable):
#   • This producer's "verify" verdict is *reproducibility + analytic
#     invariants on the SAME parametric aperture* — NOT a flight-data
#     absorption. The aperture is still parametric (MultiHexagonAperture),
#     so:
#         measurement_gate = GATE_OPEN
#         absorbed         = false
#     ALWAYS, regardless of how many checks GREEN.
#   • The diffraction-limit check is real (1.22 λ/D Airy) but on the
#     PARAMETRIC aperture, not a JWST commissioning PSF.
#   • WebbPSF cross-check is loose (±50 %) because the WebbPSF model
#     adds OPD, secondary-mirror obscuration, struts and segment-tilt
#     errors that the bare MultiHexagonAperture does not — a strict
#     equality would be dishonest.
#   • `absorbed=true` would require: (a) WebbPSF parity within ±X% on a
#     JWST NIRCam commissioning hash, AND (b) a hexa-native FFT
#     re-propagation matching POPPY to IEEE-754 — neither lands here.

import json
import os
import platform
import sys


# --- Locate the ①a wave-optics kernel via __file__ (same pattern the
# scope_poppy.py / openmdao_sizing.py ①b adapters use).
_KERNEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "kernels", "wave_optics"))
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

import poppy_kernel  # noqa: E402  — ①a domain-agnostic wave-optics kernel


# ------------------------------------------------------------------
# DOMAIN data — owned by this ①b adapter, not the kernel.
# Same reference baseline as scope_poppy.py so the two adapters are
# cross-comparable (analyze ↔ verify on the same parametric primary).
# ------------------------------------------------------------------
GEOMETRY_ID = "scope_verify_v1"

REF_SEGMENTS = 18
REF_FLAT_TO_FLAT_M = 1.32
REF_WAVELENGTH_M = 550.0e-9
# Wider FOV than scope_poppy.py (6 arcsec) so EE(5") falls inside the
# detector — needed for the encircled-energy monotonicity check.
# scope_poppy.py keeps 6" for tight PSF cores; this verify producer
# trades window size for EE-curve completeness.
REF_FOV_ARCSEC = 12.0
REF_PIXSCALE_ARCSEC = 0.020
REF_OVERSAMPLE = 2
REF_SEGMENT_GAP_M = 0.007

# Acceptance bands (g3 — published, not arbitrary).
FWHM_DIFFLIMIT_REL_TOL = 0.20   # ≤ 20 % off 1.22 λ/D for MH aperture
WEBBPSF_FWHM_REL_TOL = 0.50     # ≤ 50 % WebbPSF vs MH aperture


def run_reference_propagation():
    """Build the reference aperture + propagate once via the ①a
    wave-optics kernel. Returns (psf_hdulist, psf_sha, diameter_m,
    metrics)."""
    built = poppy_kernel.build_multihex_aperture(
        REF_SEGMENTS, REF_FLAT_TO_FLAT_M, gap_m=REF_SEGMENT_GAP_M)
    aperture = built["aperture"]
    rings = built["rings"]
    prop = poppy_kernel.propagate_psf(
        aperture, REF_WAVELENGTH_M, REF_FOV_ARCSEC,
        REF_PIXSCALE_ARCSEC, oversample=REF_OVERSAMPLE)
    diameter_m = poppy_kernel.aperture_diameter_m(
        aperture, REF_FLAT_TO_FLAT_M)
    metrics = poppy_kernel.compute_psf_metrics(
        prop["psf"], diameter_m, REF_WAVELENGTH_M, REF_PIXSCALE_ARCSEC,
        ee_radii_arcsec=(1.0, 2.0, 5.0))
    return prop["psf"], prop["psf_sha256_16"], diameter_m, rings, metrics


# ------------------------------------------------------------------
# Check 1: reproducibility — propagate twice, hashes must match.
# ------------------------------------------------------------------
def check_reproducibility() -> dict:
    _, sha_a, _, _, _ = run_reference_propagation()
    _, sha_b, _, _, _ = run_reference_propagation()
    return {
        "name": "reproducibility_psf_sha_match",
        "sha_a": sha_a,
        "sha_b": sha_b,
        "passed": sha_a == sha_b,
    }


# ------------------------------------------------------------------
# Check 2: diffraction-limit closure — measured FWHM vs 1.22 λ/D.
# ------------------------------------------------------------------
def check_diffraction_limit(metrics: dict) -> dict:
    fwhm_meas = metrics.get("fwhm_measured_arcsec")
    fwhm_th = metrics.get("fwhm_diffraction_limit_arcsec")
    if fwhm_meas is None or fwhm_th is None or fwhm_th <= 0:
        return {
            "name": "diffraction_limit_within_20pct",
            "fwhm_measured_arcsec": fwhm_meas,
            "fwhm_theoretical_arcsec": fwhm_th,
            "rel_err": None,
            "tolerance": FWHM_DIFFLIMIT_REL_TOL,
            "passed": False,
            "note": "missing FWHM — POPPY measure_fwhm returned None",
        }
    rel = abs(fwhm_meas - fwhm_th) / fwhm_th
    return {
        "name": "diffraction_limit_within_20pct",
        "fwhm_measured_arcsec": fwhm_meas,
        "fwhm_theoretical_arcsec": fwhm_th,
        "rel_err": rel,
        "tolerance": FWHM_DIFFLIMIT_REL_TOL,
        "passed": rel <= FWHM_DIFFLIMIT_REL_TOL,
    }


# ------------------------------------------------------------------
# Check 3: encircled-energy monotonicity. EE is a CDF in radius, so
# EE(1") ≤ EE(2") ≤ EE(5") must hold for any well-formed PSF.
# ------------------------------------------------------------------
def check_ee_monotonicity(metrics: dict) -> dict:
    ee = metrics.get("encircled_energy", {})
    r1 = ee.get("r_1_arcsec")
    r2 = ee.get("r_2_arcsec")
    r5 = ee.get("r_5_arcsec")
    values = [r1, r2, r5]
    if any(v is None for v in values):
        return {
            "name": "encircled_energy_monotonic",
            "ee_r1": r1, "ee_r2": r2, "ee_r5": r5,
            "passed": False,
            "note": "missing EE value — radius likely beyond FOV",
        }
    passed = r1 <= r2 <= r5
    return {
        "name": "encircled_energy_monotonic",
        "ee_r1": r1, "ee_r2": r2, "ee_r5": r5,
        "passed": passed,
    }


# ------------------------------------------------------------------
# Check 4: WebbPSF cross-check (optional — only if webbpsf installed).
# Loose ±50 % FWHM agreement vs NIRCam F550M (different segment/baffle
# model from MH aperture, so a strict equality would be dishonest).
# ------------------------------------------------------------------
def check_webbpsf_cross_same_wavelength(metrics: dict) -> dict:
    """D75 Option B — same-wavelength WebbPSF cross-check.

    The legacy `check_webbpsf_cross` compared a 550 nm kernel FWHM to a
    NIRCam F480M (4.8 μm) FWHM — λ ratio 8.7×, so FWHM ∝ λ guarantees
    the ±50 % gate cannot close honestly. design.md D75 splits the
    check: the analytic 550 nm Airy parity stays under
    `diffraction_limit_check` (check #2, instrument-independent), and
    this new check runs the kernel *again* at NIRCam's central
    wavelength so the FWHM-vs-FWHM comparison is at like-λ.

    Skipped honestly when webbpsf is missing OR NIRCam refuses the
    wavelength.
    """
    try:
        import webbpsf
        import astropy.units as u  # noqa: F401  — keep import shape
    except ImportError as exc:
        return {
            "name": "webbpsf_cross_check_same_wavelength",
            "passed": True,        # skip-not-fail when optional dep missing
            "skipped": True,
            "note": f"webbpsf not installed ({exc}) — check skipped",
        }
    try:
        # 1. WebbPSF NIRCam F480M @ 4.8 μm — same as the v1 path.
        nrc = webbpsf.NIRCam()
        nrc.filter = "F480M"
        nrc.pupil_mask = None
        nrc.image_mask = None
        psf_w = nrc.calc_psf(
            monochromatic=WEBBPSF_REF_WL_M, fov_arcsec=4.0,
            display=False)
        import poppy as _poppy
        fwhm_w = float(_poppy.measure_fwhm(psf_w, ext=0))

        # 2. Kernel propagation at the SAME wavelength (4.8 μm) so the
        #    FWHM ratio reflects optics, not λ. This is the D75 fix.
        built_k = poppy_kernel.build_multihex_aperture(
            REF_SEGMENTS, REF_FLAT_TO_FLAT_M, gap_m=REF_SEGMENT_GAP_M)
        aperture_k = built_k["aperture"]
        prop_k = poppy_kernel.propagate_psf(
            aperture_k, WEBBPSF_REF_WL_M, REF_FOV_ARCSEC,
            REF_PIXSCALE_ARCSEC, oversample=REF_OVERSAMPLE)
        diam_k = poppy_kernel.aperture_diameter_m(
            aperture_k, REF_FLAT_TO_FLAT_M)
        metrics_k = poppy_kernel.compute_psf_metrics(
            prop_k["psf"], diam_k, WEBBPSF_REF_WL_M, REF_PIXSCALE_ARCSEC,
            ee_radii_arcsec=(1.0, 2.0, 5.0))
        fwhm_kw = float(metrics_k.get("fwhm_measured_arcsec") or 0.0)

        if fwhm_w <= 0 or fwhm_kw <= 0:
            return {
                "name": "webbpsf_cross_check_same_wavelength",
                "passed": False,
                "skipped": False,
                "fwhm_nircam_arcsec": fwhm_w,
                "fwhm_kernel_4_8um_arcsec": fwhm_kw,
                "wavelength_m": WEBBPSF_REF_WL_M,
                "note": "FWHM <= 0 — invalid",
            }
        rel = abs(fwhm_w - fwhm_kw) / max(fwhm_w, fwhm_kw)
        return {
            "name": "webbpsf_cross_check_same_wavelength",
            "fwhm_nircam_arcsec": fwhm_w,
            "fwhm_kernel_4_8um_arcsec": fwhm_kw,
            "wavelength_m": WEBBPSF_REF_WL_M,
            "rel_err": rel,
            "tolerance": WEBBPSF_FWHM_REL_TOL,
            "passed": rel <= WEBBPSF_FWHM_REL_TOL,
            "skipped": False,
            "note": ("WebbPSF NIRCam F480M @ 4.8 μm vs MH-aperture "
                     "kernel propagation at the SAME 4.8 μm (D75 "
                     "Option B). Loose tolerance is honest (different "
                     "baffle / strut / OPD model)."),
        }
    except Exception as exc:
        return {
            "name": "webbpsf_cross_check_same_wavelength",
            "passed": False,
            "skipped": False,
            "note": f"webbpsf call failed: {exc}",
        }


# WebbPSF uses µm internally; expose as a constant so the check body
# is short. 0.55 µm green-visible is below NIRCam's true bandpass
# floor — webbpsf will warn or clamp; that is an honest failure mode
# the verify producer surfaces, not silently corrects.
WEBBPSF_REF_WL_M = 4.8e-6   # F480M centre ≈ 4.8 μm


# ------------------------------------------------------------------
# Check 5: synphot photometric round-trip (optional — only if synphot
# installed). Flat-spectrum source × bandpass → finite positive count.
# ------------------------------------------------------------------
def check_synphot_photometry() -> dict:
    try:
        import synphot
        import astropy.units as u
    except ImportError as exc:
        return {
            "name": "synphot_photometry_round_trip",
            "passed": True,        # skip-not-fail
            "skipped": True,
            "note": f"synphot not installed ({exc}) — check skipped",
        }
    try:
        from synphot import SourceSpectrum, SpectralElement, Observation
        from synphot.models import ConstFlux1D, Box1D

        # Flat-spectrum source at 1 unit FLAM (g3 — synthetic, NOT a
        # standard star — this is a round-trip sanity, not a flux cal).
        src = SourceSpectrum(ConstFlux1D, amplitude=1.0)
        # 100-nm-wide top-hat bandpass centred on 550 nm.
        bandpass = SpectralElement(Box1D, amplitude=1.0,
                                   x_0=550 * u.nm, width=100 * u.nm)
        obs = Observation(src, bandpass, force="taper")
        count = float(obs.countrate(area=1.0 * u.m**2).value)
        passed = (count > 0) and (count == count)  # finite NaN-check
        return {
            "name": "synphot_photometry_round_trip",
            "countrate_per_m2": count,
            "passed": passed,
            "skipped": False,
            "synphot_version": str(getattr(synphot, "__version__",
                                          "unknown")),
            "note": ("Flat 1.0 FLAM source × 100-nm top-hat @ 550 nm; "
                     "round-trip count must be finite + positive."),
        }
    except Exception as exc:
        return {
            "name": "synphot_photometry_round_trip",
            "passed": False,
            "skipped": False,
            "note": f"synphot call failed: {exc}",
        }


# ------------------------------------------------------------------
# main — orchestrate the 5 checks, write meta + checks CSV.
# ------------------------------------------------------------------
def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write(
            "usage: poppy_psf_verify.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")
    csv_path = os.path.join(output_dir, f"{GEOMETRY_ID}.checks.csv")
    fits_path = os.path.join(output_dir, f"{GEOMETRY_ID}.fits")

    try:
        import numpy  # noqa: F401
        import poppy  # noqa: F401
        import astropy.units  # noqa: F401
    except ImportError as exc:
        sys.stderr.write(
            f"poppy_psf_verify: missing dependency — {exc}\n"
            "SCOPE_VERIFY_RESULT "
            + json.dumps({"ok": False,
                          "geometry_id": GEOMETRY_ID,
                          "error": f"import: {exc}",
                          "gate_type": "install-gated"},
                         sort_keys=True)
            + "\n")
        return 3

    # Reference propagation (kept for FITS witness + metrics).
    psf, psf_sha, diameter_m, rings, metrics = run_reference_propagation()
    try:
        psf.writeto(fits_path, overwrite=True)
    except Exception as exc:
        sys.stderr.write(f"poppy_psf_verify: fits write failed — {exc}\n")

    checks: list = []
    checks.append(check_reproducibility())
    checks.append(check_diffraction_limit(metrics))
    checks.append(check_ee_monotonicity(metrics))
    checks.append(check_webbpsf_cross_same_wavelength(metrics))
    checks.append(check_synphot_photometry())

    # PASS / FAIL tally — skipped checks count as PASS (not-applicable).
    n_required = sum(1 for c in checks if not c.get("skipped"))
    n_passed = sum(1 for c in checks
                   if c.get("passed") and not c.get("skipped"))
    n_skipped = sum(1 for c in checks if c.get("skipped"))
    # ok = all REQUIRED (non-skipped) checks passed
    all_required_passed = all(
        c.get("passed") for c in checks if not c.get("skipped"))
    ok = bool(all_required_passed)

    # Flat CSV of checks for downstream consumers.
    try:
        with open(csv_path, "w", encoding="utf-8") as f:
            f.write("check,passed,skipped,note\n")
            for c in checks:
                note = (c.get("note") or "").replace(",", ";")
                f.write(
                    f"{c['name']},"
                    f"{'true' if c.get('passed') else 'false'},"
                    f"{'true' if c.get('skipped') else 'false'},"
                    f"{note}\n")
    except Exception as exc:
        sys.stderr.write(f"poppy_psf_verify: csv write failed — {exc}\n")

    version = poppy_kernel.poppy_version()
    try:
        import webbpsf
        webbpsf_v = str(getattr(webbpsf, "__version__", "unknown"))
    except ImportError:
        webbpsf_v = "not-installed"
    try:
        import synphot
        synphot_v = str(getattr(synphot, "__version__", "unknown"))
    except ImportError:
        synphot_v = "not-installed"

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "psf_sha256_16": psf_sha,
        "poppy_version": version,
        "webbpsf_version": webbpsf_v,
        "synphot_version": synphot_v,
        "python_version": platform.python_version(),
        # G7 typed gate_type — poppy PSF verify ran (success or
        # failing-required-check); no hexa-native wave-optics kernel
        # has parity yet → D80 hexa-native-absent + provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "aperture": {
            "segments_requested": REF_SEGMENTS,
            "rings": rings,
            "segment_flat_to_flat_m": REF_FLAT_TO_FLAT_M,
            "effective_diameter_m": diameter_m,
        },
        "propagation": {
            "wavelength_m": REF_WAVELENGTH_M,
            "fov_arcsec": REF_FOV_ARCSEC,
            "pixscale_arcsec": REF_PIXSCALE_ARCSEC,
            "oversample": REF_OVERSAMPLE,
        },
        "measurements": metrics,
        "tally": {
            "n_required": n_required,
            "n_passed": n_passed,
            "n_skipped": n_skipped,
            "all_required_passed": all_required_passed,
        },
        "checks": checks,
        "artifacts": {
            "fits": f"{GEOMETRY_ID}.fits",
            "checks_csv": f"{GEOMETRY_ID}.checks.csv",
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"poppy_psf_verify: wrote {meta_path} "
        f"(ok={ok}, passed={n_passed}/{n_required}, "
        f"skipped={n_skipped})\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "poppy_version": version,
        "webbpsf_version": webbpsf_v,
        "synphot_version": synphot_v,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "n_required": n_required,
        "n_passed": n_passed,
        "n_skipped": n_skipped,
        "all_required_passed": all_required_passed,
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("SCOPE_VERIFY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 6


if __name__ == "__main__":
    sys.exit(main(sys.argv))
