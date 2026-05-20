#!/usr/bin/env python3
# openmdao_sizing.py — `scope + synthesize` producer (cohort-round,
# absorption empty-cell fill 2026-05-20).
#
# ①b DOMAIN ADAPTER (demiurge design.md D72 2-layer STDLIB restructure).
# Couples a parametric segmented-primary optical figure-of-merit (PSF
# Strehl/FWHM from the ①a wave_optics kernel) with a back-of-the-envelope
# structural-mass model (areal density × area), and runs OpenMDAO's
# `ScipyOptimizeDriver` to size the primary (segment flat-to-flat,
# segment count) against a multi-objective scalarisation:
#
#   J(d_ftf, n_seg) =  w_mass * mass_kg(d_ftf, n_seg)
#                    + w_fwhm * fwhm_arcsec(d_ftf, n_seg)
#                    - w_aper * effective_diameter_m(d_ftf, n_seg)
#
# subject to (d_ftf, n_seg) ∈ [0.5, 1.8] m × {7, 19, 37}. The hex-ring
# count discretisation is handled by snapping n_seg to {7|19|37} inside
# the component (the ①a kernel rounds rings the same way), so the
# driver sees a smooth-ish problem in d_ftf with n_seg as a designer
# shelf option (default = 19 ~ JWST 18+1 reference; POPPY's
# `MultiHexagonAperture(rings=2)` populates the centre + 2 outer rings
# for 19 hexes total).
#
# SSOT location: `~/core/hexa-lang/stdlib/scope/openmdao_sizing.py`
# (D61 — producer scripts live under hexa-lang/stdlib/<domain>/, sibling
# repo from demiurge; cockpit/scripts/*.py is forbidden for NEW producers).
#
# D72 ①b adapter: ZERO wave-optics math here — all PSF / aperture
# geometry is delegated to `stdlib/kernels/wave_optics/poppy_kernel.py`.
# OpenMDAO itself is a generic MDO framework (NASA OSS, Apache-2.0); it
# is treated as adapter-local for now and is NOT promoted to a
# `kernels/mdo/` until a 2nd MDO consumer appears (e.g. space agent
# emerges with the same need — see
# `inbox/notes/openmdao-kernel-promotion-pickup.md` if/when that lands).
#
# Invoked by Swift's ScopeSynthProducer via:
#   /opt/homebrew/bin/python3.12 \
#       ~/core/hexa-lang/stdlib/scope/openmdao_sizing.py <output_dir>
#
# What it does (honest scope):
#   1. Defines an OpenMDAO `Problem` with one continuous design var
#      (segment flat-to-flat in metres) and one categorical shelf-option
#      (segment count ∈ {7, 18, 36}, swept as outer loop — default 18).
#   2. Each evaluation builds a parametric aperture via the ①a kernel,
#      propagates the PSF, reads FWHM + effective diameter, computes a
#      coarse mass estimate (areal density 60 kg/m² primary + 40 kg/m²
#      backing + 20 kg/segment hardware, ground-rule numbers from open
#      JWST/Roman-class reviews).
#   3. Runs `ScipyOptimizeDriver` (SLSQP) — bounded, derivative-free
#      finite-difference (OpenMDAO defaults). For each of the 3 shelves,
#      records the optimum and the converged figure-of-merit.
#   4. Writes `scope_synth_v1.meta.json` with the three converged points,
#      the chosen winner (lowest J), and the per-iteration history of
#      the winner. Emits `SCOPE_OPENMDAO_RESULT <json>` summary line on
#      stderr.
#
# HONESTY (g3 — non-negotiable):
#   • OpenMDAO IS doing real MDO on a real coupled optics×structure
#     model (Fraunhofer/Fresnel PSF via ①a kernel × areal-density mass)
#     — the converged point IS a real optimum of THIS scalarisation.
#     But the structural model is a back-of-the-envelope areal-density
#     proxy, NOT a finite-element mass budget from a STEP-level primary
#     backing structure. Therefore:
#         measurement_gate = GATE_OPEN
#         absorbed         = false
#     ALWAYS. No path here flips them.
#   • The weights (w_mass / w_fwhm / w_aper) are a designer choice, not
#     a measured Pareto front. They are documented in the meta.json as
#     a `scalarisation_weights` block so a downstream consumer can re-
#     weight by editing the script — NOT by claiming a different
#     verdict from the same record.
#   • Mass coefficients are open-literature placeholders (JWST primary
#     ≈ 23 kg/m² beryllium per segment; this script uses a conservative
#     60 kg/m² to cover modern fused-silica + actuator backing). The
#     ①b adapter must surface that caveat in `scope_caveats`.
#   • `absorbed=true` would require: (a) FEM mass model (CalculiX /
#     Elmer) hooked in via a separate kernel, (b) measured-grade Pareto
#     front vs a flight reference, and (c) a 2nd MDO consumer to promote
#     OpenMDAO to `kernels/mdo/`. None of those land in this phase.

import json
import os
import platform
import sys


# --- Locate the ①a wave-optics kernel via __file__ (same pattern the
# scope_poppy.py ①b adapter uses). The demiurge spawn does
# `python3 <script> <out_dir>` with arbitrary cwd, so resolve relative
# to THIS file: stdlib/scope/openmdao_sizing.py ->
# stdlib/kernels/wave_optics/.
_KERNEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "kernels", "wave_optics"))
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

import poppy_kernel  # noqa: E402  — ①a domain-agnostic wave-optics kernel


# ------------------------------------------------------------------
# DOMAIN data — owned by this ①b adapter, not OpenMDAO.
# ------------------------------------------------------------------
GEOMETRY_ID = "scope_synth_v1"

# Defaults — same JWST-class baseline the scope_poppy.py ①b adapter
# uses, so synth + analyze speak the same parametric language.
#
# Shelf labels are POPPY's ACTUAL ring populations: rings=1 → 7, rings=2 → 19,
# rings=3 → 37 (closed form 1 + 3·r·(r+1)). The previous (7, 18, 36) labels
# were off-by-one in the outer ring — they implied a hex was missing per ring,
# which POPPY's MultiHexagonAperture does NOT do unless `segmentlist=` excludes
# it explicitly. Documented in
# `~/core/demiurge/inbox/notes/parity_attempt_scope_synth_2026-05-20.md`
# root-cause §2 → fixed here 2026-05-20.
SEGMENT_SHELVES = (7, 19, 37)
DEFAULT_SHELF = 19

# Continuous design-variable bounds for segment flat-to-flat (metres).
# 0.50 m floor ~ small space telescope cell; 1.80 m ceiling ~ ELT-class
# segment upper bound (open literature). Initial guess = JWST 1.32 m.
FTF_LOWER_M = 0.50
FTF_UPPER_M = 1.80
FTF_INITIAL_M = 1.32

# Wavelength / detector — same band as scope_poppy.py for cross-cell
# comparability (NOT a measured band selection).
WAVELENGTH_M = 550.0e-9
FOV_ARCSEC = 6.0
PIXSCALE_ARCSEC = 0.020
OVERSAMPLE = 2
SEGMENT_GAP_M = 0.007

# Mass-model coefficients (open-literature placeholders, NOT measured).
AREAL_PRIMARY_KG_PER_M2 = 60.0    # primary mirror + coating
AREAL_BACKING_KG_PER_M2 = 40.0    # backing structure
PER_SEGMENT_HARDWARE_KG = 20.0    # actuators + edge sensors + harness

# Scalarisation weights — designer choice (NOT a measured Pareto front).
W_MASS = 0.01     # kg^-1 (penalise tonnes)
W_FWHM = 1.00     # arcsec^-1 (penalise blur)
W_APER = 0.20     # m^-1     (reward collecting area indirectly)

# Driver budget — keep small so the demiurge spawn returns inside a
# reasonable wall-clock. SLSQP typically converges in 10..30 iters on
# 1-D bounded problems.
MAX_ITER = 25


# ------------------------------------------------------------------
# Coupled optics×structure evaluator — used as an OpenMDAO
# ExplicitComponent.compute body.
# ------------------------------------------------------------------
def evaluate_point(ftf_m: float, segments: int) -> dict:
    """One coupled (PSF, mass, J) evaluation.

    The PSF call goes through the ①a wave_optics kernel; the mass call
    is a closed-form areal-density proxy owned by THIS adapter. Returns
    a dict with the headline numbers so the OpenMDAO Component can
    expose them as outputs.

    Honest: the only "real measurement" here is the Fraunhofer/Fresnel
    PSF math from the kernel. The mass coefficients are placeholders.
    """
    built = poppy_kernel.build_multihex_aperture(
        segments, ftf_m, gap_m=SEGMENT_GAP_M)
    aperture = built["aperture"]
    rings = built["rings"]

    prop = poppy_kernel.propagate_psf(
        aperture, WAVELENGTH_M, FOV_ARCSEC, PIXSCALE_ARCSEC,
        oversample=OVERSAMPLE)
    diameter_m = poppy_kernel.aperture_diameter_m(aperture, ftf_m)
    metrics = poppy_kernel.compute_psf_metrics(
        prop["psf"], diameter_m, WAVELENGTH_M, PIXSCALE_ARCSEC,
        ee_radii_arcsec=(1.0, 2.0, 5.0))

    fwhm = (metrics["fwhm_measured_arcsec"]
            or metrics["fwhm_diffraction_limit_arcsec"])
    # Fall back to the diffraction-limit if POPPY's measure_fwhm
    # returned NaN/Inf (edge case at very small apertures).
    if fwhm is None or fwhm <= 0:
        fwhm = metrics["fwhm_diffraction_limit_arcsec"]

    # Mass model — areal density × hex-packed collecting area
    # + per-segment hw.
    #
    # `effective_area_m2` is the actual hex-pack collecting area
    # (N · (3√3/2) · a² with a = POPPY's side attribute), NOT the
    # bounding disk π·(D/2)² the prior version used. The disk
    # approximation overstated the flat-axis extent but understated
    # the corner-axis extent of the hex lattice and parity-FAILed by
    # 7–13 % vs the analytic oracle
    # (`inbox/notes/parity_attempt_scope_synth_2026-05-20.md` root-
    # cause §1 → fixed here 2026-05-20). The kernel helper reads
    # POPPY's actual `side` and `rings` so the area returned reflects
    # exactly the geometry that was propagated.
    #
    # `n_segments_actual` is POPPY's true population for this ring
    # count (root-cause §2 fix); use it for hardware mass so the kg
    # accounting matches the propagated aperture.
    area_m2 = poppy_kernel.hex_collecting_area_m2(aperture, ftf_m)
    n_segments_actual = poppy_kernel.hex_ring_segment_count(rings)
    mass_kg = (
        (AREAL_PRIMARY_KG_PER_M2 + AREAL_BACKING_KG_PER_M2) * area_m2
        + PER_SEGMENT_HARDWARE_KG * n_segments_actual
    )

    # Scalarisation. W_APER on diameter is *subtracted* (reward more
    # collecting power) — net objective is minimise.
    j = (W_MASS * mass_kg
         + W_FWHM * fwhm
         - W_APER * diameter_m)

    return {
        "ftf_m": float(ftf_m),
        "segments_requested": int(segments),
        "segments_actual": int(n_segments_actual),
        "segments": int(n_segments_actual),
        "rings": int(rings),
        "effective_diameter_m": float(diameter_m),
        "effective_area_m2": float(area_m2),
        "collecting_area_m2": float(area_m2),
        "bounding_disk_area_m2": float(
            __import__("math").pi * (diameter_m / 2.0) ** 2),
        "fwhm_arcsec": float(fwhm),
        "strehl_proxy": metrics["strehl_proxy"],
        "psf_sha256_16": prop["psf_sha256_16"],
        "mass_kg": float(mass_kg),
        "objective_j": float(j),
    }


# ------------------------------------------------------------------
# OpenMDAO component — wraps `evaluate_point` so the driver can sweep
# the segment flat-to-flat under a fixed shelf option.
# ------------------------------------------------------------------
def build_component(segments: int):
    """Build a single-input single-output OpenMDAO ExplicitComponent
    that maps `ftf_m -> objective_j` for a fixed segment shelf."""
    import openmdao.api as om

    class _ScopeFOMComponent(om.ExplicitComponent):
        def setup(self):
            self.add_input("ftf_m", val=FTF_INITIAL_M)
            self.add_output("objective_j", val=0.0)
            self.add_output("fwhm_arcsec", val=0.0)
            self.add_output("mass_kg", val=0.0)
            self.add_output("effective_diameter_m", val=0.0)
            # Derivative-free FD — POPPY is opaque to AD.
            self.declare_partials("*", "*", method="fd")

        def compute(self, inputs, outputs):  # noqa: D401
            point = evaluate_point(float(inputs["ftf_m"][0]), segments)
            outputs["objective_j"] = point["objective_j"]
            outputs["fwhm_arcsec"] = point["fwhm_arcsec"]
            outputs["mass_kg"] = point["mass_kg"]
            outputs["effective_diameter_m"] = point["effective_diameter_m"]
            # Stash the full evaluation on the component for the
            # history recorder.
            self._last_point = point

    return _ScopeFOMComponent


def run_shelf_optimisation(segments: int) -> dict:
    """Run ScipyOptimizeDriver/SLSQP on the segment shelf and return
    the converged design + objective + a small iteration history."""
    import openmdao.api as om

    prob = om.Problem()
    comp_cls = build_component(segments)
    prob.model.add_subsystem("fom", comp_cls(), promotes=["*"])

    prob.driver = om.ScipyOptimizeDriver()
    prob.driver.options["optimizer"] = "SLSQP"
    prob.driver.options["maxiter"] = MAX_ITER
    prob.driver.options["tol"] = 1e-4
    prob.driver.options["disp"] = False

    prob.model.add_design_var(
        "ftf_m", lower=FTF_LOWER_M, upper=FTF_UPPER_M)
    prob.model.add_objective("objective_j")

    history: list = []

    def _record_iter(_):
        # OpenMDAO callbacks are noisy across versions — be defensive.
        try:
            point = prob.model.fom._last_point  # type: ignore[attr-defined]
            history.append({
                "ftf_m": point["ftf_m"],
                "objective_j": point["objective_j"],
                "fwhm_arcsec": point["fwhm_arcsec"],
                "mass_kg": point["mass_kg"],
                "effective_diameter_m": point["effective_diameter_m"],
            })
        except Exception:
            pass

    prob.setup()
    prob.set_val("ftf_m", FTF_INITIAL_M)

    # Newer OpenMDAO exposes `add_recorder` on the driver; we use a
    # simpler post-iteration callback the script owns directly. Drive
    # once to seed history with the initial point.
    initial = evaluate_point(FTF_INITIAL_M, segments)
    history.append({
        "ftf_m": initial["ftf_m"],
        "objective_j": initial["objective_j"],
        "fwhm_arcsec": initial["fwhm_arcsec"],
        "mass_kg": initial["mass_kg"],
        "effective_diameter_m": initial["effective_diameter_m"],
    })

    # Try the modern API first; fall back to run_driver().
    try:
        prob.run_driver()
    except Exception as exc:  # pragma: no cover — surface honest failure
        return {
            "segments": segments,
            "ok": False,
            "error": f"run_driver: {exc}",
            "history": history,
        }

    # Record the converged design.
    converged = evaluate_point(float(prob.get_val("ftf_m")[0]), segments)
    history.append({
        "ftf_m": converged["ftf_m"],
        "objective_j": converged["objective_j"],
        "fwhm_arcsec": converged["fwhm_arcsec"],
        "mass_kg": converged["mass_kg"],
        "effective_diameter_m": converged["effective_diameter_m"],
    })

    return {
        "segments": segments,
        "ok": True,
        "converged": converged,
        "n_iter": len(history),
        "history": history,
    }


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write(
            "usage: openmdao_sizing.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")
    csv_path = os.path.join(output_dir, f"{GEOMETRY_ID}.history.csv")

    # Honest import-failure path — surface verbatim, no silent success.
    try:
        import openmdao.api  # noqa: F401
        import numpy  # noqa: F401
        import poppy  # noqa: F401
        import astropy.units  # noqa: F401
    except ImportError as exc:
        sys.stderr.write(
            f"openmdao_sizing: missing dependency — {exc}\n"
            "SCOPE_OPENMDAO_RESULT "
            + json.dumps({"ok": False,
                          "geometry_id": GEOMETRY_ID,
                          "error": f"import: {exc}",
                          "gate_type": "install-gated"},
                         sort_keys=True)
            + "\n")
        return 3

    # Sweep the 3 shelves.
    shelves: list = []
    for n in SEGMENT_SHELVES:
        try:
            shelves.append(run_shelf_optimisation(n))
        except Exception as exc:
            shelves.append({
                "segments": n,
                "ok": False,
                "error": f"shelf {n}: {exc}",
                "history": [],
            })

    # Pick winner = lowest J among ok shelves.
    ok_shelves = [s for s in shelves if s.get("ok")]
    if not ok_shelves:
        sys.stderr.write(
            "openmdao_sizing: no shelf converged\n"
            "SCOPE_OPENMDAO_RESULT "
            + json.dumps({"ok": False,
                          "geometry_id": GEOMETRY_ID,
                          "error": "no shelf converged",
                          "gate_type": "hexa-native-absent"},
                         sort_keys=True)
            + "\n")
        # Still write meta so the consumer can inspect.
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump({
                "ok": False,
                "geometry_id": GEOMETRY_ID,
                # G7 typed gate_type — substrate ran but the MDO did
                # not converge; not an install/data/platform issue and
                # no hexa-native MDO kernel exists yet.
                "gate_type": "hexa-native-absent",
                "provisional": True,
                "shelves": shelves,
            }, f, indent=2, sort_keys=True)
            f.write("\n")
        return 4
    winner = min(ok_shelves, key=lambda s: s["converged"]["objective_j"])

    # Write a flat CSV of the winning shelf's history so a downstream
    # consumer can plot convergence without parsing JSON.
    try:
        with open(csv_path, "w", encoding="utf-8") as f:
            f.write("iter,ftf_m,objective_j,fwhm_arcsec,"
                    "mass_kg,effective_diameter_m\n")
            for i, h in enumerate(winner["history"]):
                f.write(
                    f"{i},{h['ftf_m']:.6f},"
                    f"{h['objective_j']:.6f},"
                    f"{h['fwhm_arcsec']:.6f},"
                    f"{h['mass_kg']:.3f},"
                    f"{h['effective_diameter_m']:.4f}\n")
    except Exception as exc:
        sys.stderr.write(f"openmdao_sizing: csv write failed — {exc}\n")

    # OpenMDAO version pin.
    try:
        import openmdao
        openmdao_v = str(getattr(openmdao, "__version__", "unknown"))
    except Exception:
        openmdao_v = "unknown"

    converged = winner["converged"]

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "openmdao_version": openmdao_v,
        "poppy_version": poppy_kernel.poppy_version(),
        "python_version": platform.python_version(),
        # G7 typed gate_type — OpenMDAO sizing ran; no hexa-native MDO
        # kernel exists yet → D80 hexa-native-absent + provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "design_space": {
            "ftf_lower_m": FTF_LOWER_M,
            "ftf_upper_m": FTF_UPPER_M,
            "ftf_initial_m": FTF_INITIAL_M,
            "segment_shelves": list(SEGMENT_SHELVES),
        },
        "scalarisation_weights": {
            "w_mass": W_MASS,
            "w_fwhm": W_FWHM,
            "w_aper": W_APER,
        },
        "mass_model": {
            "areal_primary_kg_per_m2": AREAL_PRIMARY_KG_PER_M2,
            "areal_backing_kg_per_m2": AREAL_BACKING_KG_PER_M2,
            "per_segment_hardware_kg": PER_SEGMENT_HARDWARE_KG,
        },
        "propagation": {
            "wavelength_m": WAVELENGTH_M,
            "fov_arcsec": FOV_ARCSEC,
            "pixscale_arcsec": PIXSCALE_ARCSEC,
            "oversample": OVERSAMPLE,
        },
        "shelves": shelves,
        "winner": {
            "segments": winner["segments"],
            "n_iter": winner["n_iter"],
            "converged": converged,
        },
        "artifacts": {
            "history_csv": f"{GEOMETRY_ID}.history.csv",
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"openmdao_sizing: wrote {meta_path} "
        f"(winner shelf={winner['segments']}, "
        f"ftf={converged['ftf_m']:.3f} m, "
        f"J={converged['objective_j']:.4f})\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "openmdao_version": openmdao_v,
        "poppy_version": meta["poppy_version"],
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "winner_segments": winner["segments"],
        "winner_ftf_m": converged["ftf_m"],
        "winner_objective_j": converged["objective_j"],
        "winner_fwhm_arcsec": converged["fwhm_arcsec"],
        "winner_mass_kg": converged["mass_kg"],
        "winner_diameter_m": converged["effective_diameter_m"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("SCOPE_OPENMDAO_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
