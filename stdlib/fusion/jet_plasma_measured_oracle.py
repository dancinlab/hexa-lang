#!/usr/bin/env python3
# jet_plasma_measured_oracle.py — REAL (or honest-fallback) measured-
# oracle producer for Ufo / sister-substrate fusion plasma diagnostic.
#
# κ-70 G37 · RFC 013 §6.11 · demiurge design.md D118 (κ-70 G36 cell-
# pick lock-in) / D119 (κ-70 G37 first-flip) · supersedes any
# illustrative-physics `mc_slab_demo` for the *measured-oracle* axis.
# This is the κ-70 THIRD cell `absorbed=true` legitimate flip target
# (Ufo Stage-2 sister-substrate fusion plasma diagnostic · JET open-
# pulse archive mid-Ohmic single shot · Debye-length λ_D axis vs
# hexa-native `plasma_metrics_kernel::lambda_d`).
#
# Pattern: byte-equivalent mirror of `sleep_edf_measured_oracle.py`
# (κ-69 G33 D117 — Aura/EEG second-flip) and `nrel_midc_pyranometer.
# py` (κ-68 G29 D110 — Energy/solar first-flip). One Python script
# orchestrates the fetch + bridge + hexa-native + parity-stat +
# JSON-emit.
#
# Honest scope (g3 — non-negotiable, D119 honesty floor):
#
#   * Dataset: JET (Joint European Torus) D-T 1997 DTE1 reference
#     operating point (mid-Ohmic stationary single shot · n_e ≈ 5e19
#     m⁻³, T_e ≈ 10 keV — Keilhacker et al., Nucl. Fusion 39 (1999)
#     209-234 · doi:10.1088/0029-5515/39/2/306). Per-shot timeseries
#     fetch path: `jet_pulse_fetcher.py` (D86 floor · CLI/env-var
#     only). Anonymous open access to a real raw JET pulse n_e + T_e
#     timeseries is NOT available as of writing (EUROfusion portal
#     SSO + IMAS UDA REST token requirements) — the fetcher falls
#     back to a *synthetic JET-like mid-Ohmic stationary profile*
#     around the textbook reference operating point. This is the
#     D118 exit-criterion-δ permitted shape · disclosed in
#     `dataset_caveats`.
#
#   * Trusted bridge: `plasmapy.formulary.lengths.Debye_length` if
#     plasmapy is importable in the producer env. plasmapy is the
#     community-validated plasma-physics library; same trust role
#     pvlib Ineichen plays in κ-68 G29 (D109) and MNE Welch plays
#     in κ-69 G33 (D117). When plasmapy is unavailable, the
#     trusted-bridge falls back to a Python `math`-only textbook
#     closed-form using CODATA-2022 constants (the SAME closed-form
#     `plasma_metrics_kernel_test.hexa` parity-tests against at
#     rel_err = 0.0). Disclosed in `dataset_caveats`.
#
#   * Modeled side: hexa-native `plasma_metrics_kernel::lambda_d`
#     (41/41 PASS @ rel_err = 0.0 IEEE-754 bit-exact vs hand-mirrored
#     Python `math` reference · `pilot-plasma_metrics` row in
#     PILOTS.demi). For each (n_e, T_e) stationary timestep we
#     invoke `plasma_metrics_kernel::lambda_d(T_e_eV, n_e_m3)` via
#     `_plasma_lambda_d_batch.hexa` and compare to the trusted-bridge
#     λ_D on the SAME inputs. The PASS criterion (mean_rel_err ≤
#     0.05 from D118) is the honest measured statement that the
#     hexa kernel's closed-form evaluation tracks the trusted-bridge
#     λ_D over the JET-like stationary timesteps.
#
#   * PASS gate: mean_rel_err = mean(|bridge_lambda - hexa_lambda| /
#     |bridge_lambda|) over N=50 mid-Ohmic stationary timesteps ≤ 0.05.
#
#   * `absorbed=true` is set EXPLICITLY by THIS producer based on
#     the PASS gate. D95 computed projection is NOT in this path
#     (D103 dimension separation — `hexa_native_parity` left nil;
#     substrate-parity is a separate axis carried by PILOTS.demi
#     `[pilot-plasma_metrics]`).
#
#   * D106 illustrative-physics exclusion APPLIES PARTIALLY (D118
#     g3 carve-out): only Ufo Stage-2 sister-substrate fusion
#     plasma diagnostic axis is non-illustrative. Ufo Stage-4..7
#     (warp / wormhole / dim / use) are explicitly excluded — the
#     emitted record's `scope_caveats` array carries that carve-out
#     as a mandatory entry (D118 cross-link gate).
#
#   * PASS shape honesty (D119 mirror of D117 g3 paragraph): the
#     λ_D evaluation is *formula evaluation* on real-or-JET-like
#     measured (n_e, T_e), NOT *prediction vs measurement* in the
#     D110 G29 modeling-error sense. If `mean_rel_err` lands at
#     1e-12 .. 1e-15 (which the bit-exact substrate-parity floor
#     suggests for the plasmapy-bridged path), that's the natural
#     consequence of the kernel and the bridge sharing CODATA
#     constants + identical closed-form. The PASS is a numeric-
#     equivalence statement (D117 G33 mirror shape), not a
#     prediction-axis honesty claim. Disclosed in `scope_caveats`.
#
# Invocation:
#   python3 jet_plasma_measured_oracle.py <output_dir> \
#     [cache_dir=/tmp/jet_pulse] [pulse_id=JET-42976]
#
# Exit: 0 on success (record + absorbed=true|false honestly emitted),
#       2 usage, 3 fetch failure, 4 hexa-native batch failure,
#       5 oracle-compute failure.

import json
import math
import os
import platform
import subprocess
import sys
import time

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
JET_PULSE_FETCHER = os.path.join(_THIS_DIR, "jet_pulse_fetcher.py")
HEXA_LAMBDA_D_BATCH = os.path.join(_THIS_DIR, "_plasma_lambda_d_batch.hexa")

# Point the hexa loader at THIS worktree's stdlib root so
# `use "stdlib/kernels/plasma/plasma_metrics_kernel"` resolves.
_HEXA_REPO_ROOT = os.path.abspath(os.path.join(_THIS_DIR, "..", ".."))
_HEXA_ENV = {**os.environ, "HEXA_LANG": _HEXA_REPO_ROOT}

PRODUCER_ID = "jet_plasma_measured_oracle"

# D118 PASS threshold. Locked-in by design.md D118; MUST NOT be
# tuned post-hoc.
PASS_THRESHOLD = 0.05

# CODATA-2022 constants (must match `plasma_metrics_kernel.hexa`
# exactly — see the kernel header). The math-fallback bridge uses
# these directly when plasmapy is unavailable.
ELEMENTARY_CHARGE_C = 1.602176634e-19    # exact (2019 SI)
EPSILON_0_F_PER_M = 8.8541878128e-12     # CODATA 2022


def _run_fetcher(cache_dir, pulse_id):
    """Spawn jet_pulse_fetcher; return parsed meta dict from sidecar."""
    args = [sys.executable, JET_PULSE_FETCHER, cache_dir]
    if pulse_id:
        args.append(pulse_id)
    proc = subprocess.run(args, capture_output=True, text=True,
                          timeout=600)
    if proc.returncode != 0:
        raise RuntimeError(
            f"jet_pulse_fetcher failed (rc={proc.returncode}): "
            f"{proc.stderr.strip()[:400]}")
    meta = None
    for line in proc.stderr.splitlines():
        if line.startswith("JET_PULSE_FETCH_RESULT "):
            body = line[len("JET_PULSE_FETCH_RESULT "):]
            meta = json.loads(body)
            break
    if meta is None:
        raise RuntimeError("jet_pulse_fetcher emitted no result line")
    with open(meta["meta_path"]) as f:
        full = json.load(f)
    return full


def _bridge_lambda_d(rows, bridge_kind):
    """Compute trusted-bridge λ_D for each (n_e_m3, T_e_eV) row.

    Returns (list[float], str) — the per-step λ_D values [m] and a
    short identifier describing which bridge was actually used
    (`plasmapy-X.Y.Z` or `math-codata2022-textbook-closed-form`).
    """
    if bridge_kind in (None, "", "auto", "plasmapy"):
        # Prefer plasmapy when available — community-validated bridge.
        try:
            import astropy.units as u
            from plasmapy.formulary.lengths import Debye_length
            import plasmapy as _plasmapy
            vals = []
            for n_e_m3, t_e_ev in rows:
                # plasmapy expects temperature in K. eV → K via
                # T_K = T_eV · e / k_B. We use astropy.units to let
                # plasmapy do the conversion (eV is a known unit).
                lam = Debye_length(t_e_ev * u.eV, n_e_m3 / (u.m ** 3))
                vals.append(float(lam.to(u.m).value))
            return vals, f"plasmapy-{_plasmapy.__version__}"
        except Exception as exc:
            sys.stderr.write(
                f"jet_plasma_measured_oracle: plasmapy bridge "
                f"unavailable ({type(exc).__name__}: {exc}); "
                f"falling back to math-codata2022 textbook closed-"
                f"form.\n")
            # fall through to math fallback
    # Math fallback — identical closed-form to plasma_metrics_kernel
    # using CODATA-2022 constants.
    vals = []
    for n_e_m3, t_e_ev in rows:
        # λ_D = sqrt(ε₀ · T_e_eV / (n_e · e))  (using k_B·T = T_eV · e)
        lam = math.sqrt(
            EPSILON_0_F_PER_M * t_e_ev /
            (n_e_m3 * ELEMENTARY_CHARGE_C))
        vals.append(lam)
    return vals, "math-codata2022-textbook-closed-form"


def _hexa_lambda_d_batch(sidecar_path, n_steps):
    """Spawn the hexa-native λ_D batch wrapper. Returns list[float]
    of length n_steps (per-timestep λ_D in metres)."""
    cmd = [
        "hexa", "run", HEXA_LAMBDA_D_BATCH,
        sidecar_path, str(n_steps),
    ]
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=900,
        env=_HEXA_ENV)
    if proc.returncode != 0:
        raise RuntimeError(
            f"hexa plasma_lambda_d batch failed (rc={proc.returncode}): "
            f"{proc.stderr.strip()[:400]}")
    lines = [ln for ln in proc.stdout.strip().split("\n") if ln.strip()]
    if len(lines) != n_steps:
        raise RuntimeError(
            f"hexa lambda_d batch returned {len(lines)} lines, "
            f"expected {n_steps}")
    return [float(ln) for ln in lines]


def _read_profile(sidecar_path, n_steps):
    """Re-read the (n_e_m3, T_e_eV) sidecar produced by the fetcher.

    Returns list[(n_e, T_e)] of length exactly n_steps.
    """
    rows = []
    with open(sidecar_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            try:
                n_e = float(parts[0])
                t_e = float(parts[1])
            except ValueError:
                continue
            rows.append((n_e, t_e))
            if len(rows) >= n_steps:
                break
    if len(rows) < n_steps:
        raise RuntimeError(
            f"sidecar has {len(rows)} valid rows; need {n_steps}")
    return rows


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(
            "usage: jet_plasma_measured_oracle.py <output_dir> "
            "[cache_dir] [pulse_id]\n")
        return 2

    output_dir = argv[1]
    cache_dir = argv[2] if len(argv) >= 3 else os.environ.get(
        "JET_PULSE_CACHE_DIR", "/tmp/jet_pulse")
    pulse_id = argv[3] if len(argv) >= 4 else os.environ.get(
        "JET_PULSE_ID", "")  # fetcher applies its own default

    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(cache_dir, exist_ok=True)

    # Stage 1: fetch + slice.
    t0 = time.time()
    try:
        fetcher_meta = _run_fetcher(cache_dir, pulse_id)
    except Exception as exc:
        sys.stderr.write(
            f"jet_plasma_measured_oracle: fetcher failed: "
            f"{type(exc).__name__}: {exc}\n")
        return 3
    t_fetch = time.time() - t0

    sidecar_path = fetcher_meta["sidecar_path"]
    n_steps = int(fetcher_meta["n_steps"])
    data_source = fetcher_meta.get("data_source", "unknown")
    pulse_resolved = fetcher_meta.get("pulse_id", pulse_id or "unknown")

    # Stage 2: bridge λ_D (trusted oracle).
    t0 = time.time()
    try:
        rows = _read_profile(sidecar_path, n_steps)
        bridge_kind_arg = os.environ.get("JET_LAMBDA_D_BRIDGE", "auto")
        bridge_vals, bridge_id = _bridge_lambda_d(rows, bridge_kind_arg)
    except Exception as exc:
        sys.stderr.write(
            f"jet_plasma_measured_oracle: bridge λ_D failed: "
            f"{type(exc).__name__}: {exc}\n")
        return 5
    t_bridge = time.time() - t0

    # Stage 3: hexa-native λ_D batch.
    t0 = time.time()
    try:
        hexa_vals = _hexa_lambda_d_batch(sidecar_path, n_steps)
    except Exception as exc:
        sys.stderr.write(
            f"jet_plasma_measured_oracle: hexa λ_D batch failed: "
            f"{type(exc).__name__}: {exc}\n")
        return 4
    t_hexa = time.time() - t0

    # Stage 4: parity stats. mean_rel_err = mean(|bridge - hexa| /
    # |bridge|). For closed-form λ_D with identical CODATA constants
    # this should land at IEEE-754 rounding (1e-15 .. 1e-13 depending
    # on operation order). The 5% threshold (D118) is the κ-68 G29 /
    # κ-69 G33 mirror — same invariant audit threshold across all
    # three cells, even though this cell's PASS shape is numeric-
    # equivalence (D117 mirror, not D110 predict-vs-measure).
    eps = 1e-300
    rel_errs = []
    for b, h in zip(bridge_vals, hexa_vals):
        denom = abs(b) if abs(b) > eps else eps
        rel_errs.append(abs(b - h) / denom)
    mean_rel_err = sum(rel_errs) / len(rel_errs) if rel_errs else float("inf")
    max_rel_err = max(rel_errs) if rel_errs else float("inf")

    pass_flag = mean_rel_err <= PASS_THRESHOLD

    # Build the measured_oracle block — mirrors κ-69 D117 shape.
    try:
        import platform as _pl
        py_ver = _pl.python_version()
    except Exception:
        py_ver = "unknown"

    measured_oracle = {
        "oracle_source": (
            f"JET D-T 1997 DTE1 reference operating point · "
            f"pulse {pulse_resolved} · {n_steps} mid-Ohmic "
            f"stationary timesteps · trusted-bridge λ_D from "
            f"{bridge_id} (textbook closed-form NRL Formulary "
            f"p.34 + Krall & Trivelpiece ch.1)"
        ),
        "unit": "m (Debye length)",
        "sample_count": n_steps,
        "mean_rel_err": mean_rel_err,
        "max_rel_err": max_rel_err,
        "threshold": PASS_THRESHOLD,
        "dataset_caveats": (
            f"N={n_steps} mid-Ohmic stationary timesteps with "
            f"reference operating point n_e={fetcher_meta['ref_n_e_m3']:.3g} "
            f"m⁻³ + T_e={fetcher_meta['ref_T_e_eV']:.3g} eV "
            f"(JET D-T 1997 textbook reference). data_source = "
            f"`{data_source}` (D118 exit-criterion-δ: anonymous "
            f"access to raw JET pulse archive is not available as "
            f"of 2026-05; when real-JET fetch is unreachable, the "
            f"fetcher emits a synthetic JET-like mid-Ohmic "
            f"stationary profile around the textbook reference "
            f"operating point with ±{fetcher_meta['fluc_frac']:.2%} "
            f"uniform fluctuation · seed={fetcher_meta['fluc_seed']} "
            f"· honest fallback disclosed here). modeled = HEXA-"
            f"NATIVE `plasma_metrics_kernel::lambda_d` (`pilot-"
            f"plasma_metrics` 41/41 PASS @ rel_err = 0.0 IEEE-754 "
            f"bit-exact vs hand-mirrored Python `math` textbook "
            f"reference · NRL Formulary p.34 + Krall & Trivelpiece "
            f"ch.1 closed-form). trusted bridge = {bridge_id} on "
            f"the SAME (n_e, T_e) inputs."
        ),
        "dataset_citation": (
            "Keilhacker et al., Nucl. Fusion 39 (1999) 209-234 · "
            "doi:10.1088/0029-5515/39/2/306 (JET D-T 1997 DTE1 "
            "campaign reference operating point); λ_D textbook = "
            "NRL Plasma Formulary 2019 ed. p.34 + Krall & "
            "Trivelpiece 'Principles of Plasma Physics' ch.1 (1973)"
        ),
    }

    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    absorbed = bool(pass_flag)

    # D118 g3 carve-out — Stage-4..7 illustrative-physics exclusion.
    # The first scope_caveat entry is MANDATORY (D118 cross-link gate).
    stage_carve_out = (
        "Stage-2 sister-substrate fusion plasma diagnostic axis "
        "only — Stage-4..7 (warp/wormhole/dim/use) excluded per "
        "D106 illustrative-physics gate · RFC 013 §6.12 anti-"
        "conflation"
    )

    record = {
        "domain": "ufo",
        "verb": "verify",
        "kind": "jet_pulse_lambda_d_measured_oracle",
        "stamp": stamp,
        "producer": PRODUCER_ID,
        "measurement_gate": (
            "GATE_CLOSED_MEASURED" if absorbed else "GATE_OPEN"
        ),
        # κ-70 G37 third cell `absorbed=true` legitimate-flip target.
        # Writer (this producer) sets `absorbed` explicitly based on
        # `measured_oracle.mean_rel_err <= D118 threshold`. D95
        # computed projection is NOT in this path (D103 separation).
        "absorbed": absorbed,
        "scope_caveats": [
            stage_carve_out,
            (
                f"single JET-like mid-Ohmic stationary pulse "
                f"({pulse_resolved} · data_source = "
                f"`{data_source}`); mean rel_err over {n_steps} "
                f"timesteps of trusted-bridge λ_D ({bridge_id}) "
                f"vs hexa-native `plasma_metrics_kernel::lambda_d` "
                f"(`pilot-plasma_metrics` 41/41 PASS @ rel_err = "
                f"0.0 IEEE-754 bit-exact = substrate-parity floor). "
                f"PASS shape = numeric-equivalence (D117 G33 mirror) "
                f"NOT predict-vs-measure (D110 G29 modeling-error "
                f"shape). The bit-exact substrate-parity floor + "
                f"identical CODATA-2022 constants in kernel + "
                f"bridge means residual rel_err is IEEE-754 "
                f"rounding noise, not modeling honesty evidence."
            ),
            (
                f"Real-JET open-pulse anonymous-access fetch is "
                f"not available as of 2026-05 (EUROfusion portal "
                f"SSO + IMAS UDA REST token requirements). When "
                f"unreachable the fetcher falls back to a "
                f"synthetic JET-like mid-Ohmic stationary profile "
                f"around the JET D-T 1997 textbook reference "
                f"operating point (n_e ≈ 5e19 m⁻³, T_e ≈ 10 keV) "
                f"with ±{fetcher_meta['fluc_frac']:.2%} uniform "
                f"fluctuation. Override via $JET_PULSE_URL "
                f"(D86-clean caller-supplied URL · per-shot raw "
                f"timeseries fetch axis is the follow-on horizontal "
                f"extension once real JET archive open access "
                f"stabilises)."
            ),
            (
                f"trusted-bridge λ_D = {bridge_id}. plasmapy is the "
                f"community-validated plasma-physics library (same "
                f"trust role pvlib Ineichen plays in κ-68 G29 / "
                f"D110 and MNE Welch plays in κ-69 G33 / D117). "
                f"When plasmapy is unavailable in the producer "
                f"env, the fallback bridge is a Python `math`-only "
                f"textbook closed-form using CODATA-2022 constants "
                f"— identical to the hexa kernel's closed-form. "
                f"The hexa-native scope for κ-70 G37 is "
                f"`plasma_metrics_kernel::lambda_d` alone (D118 "
                f"explicit decision); ω_p / Larmor radius / ln Λ "
                f"are follow-on axes."
            ),
        ],
        "citations": [
            "demiurge design.md D118 — κ-70 G36 cell-pick lock-in "
            "(Ufo Stage-2 plasma · JET pulse archive · 5-fold)",
            "demiurge design.md D119 — κ-70 G37 first-flip (this "
            "record's anchor · D117 mirror)",
            "demiurge proposals/rfc_013_hexa_native_parity_connection."
            "md §6.11 — per-cell measured-oracle parity round",
            "demiurge design.md D106 — illustrative-physics carve-"
            "out (Stage-4..7 anti-conflation gate)",
            "Keilhacker et al., Nucl. Fusion 39 (1999) 209-234 · "
            "doi:10.1088/0029-5515/39/2/306 (JET D-T 1997 reference)",
            "NRL Plasma Formulary 2019 ed., p.34 (Debye length "
            "closed-form)",
            (
                "hexa-lang `stdlib/kernels/plasma/plasma_metrics_"
                "kernel.hexa` · `pilot-plasma_metrics` 41/41 PASS "
                "@ rel_err = 0.0 IEEE-754 bit-exact"
            ),
            f"trusted-bridge λ_D = {bridge_id}",
        ],
        "falsifiers": None,
        # D103 dimension-separation — substrate-parity axis left null
        # here (carried separately by PILOTS.demi `[pilot-plasma_
        # metrics]` 41/41 PASS).
        "hexa_native_parity": None,
        "alien_index": None,
        "skipped_reason": None,
        # κ-70 G37 / D119 — measured-oracle axis populated from
        # JET-like mid-Ohmic stationary profile.
        "measured_oracle": measured_oracle,
    }

    out_path = os.path.join(
        output_dir,
        f"ufo_verify_{stamp}_{PRODUCER_ID}.json")
    with open(out_path, "w") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "producer": PRODUCER_ID,
        "stamp": stamp,
        "pulse_id": pulse_resolved,
        "data_source": data_source,
        "bridge_id": bridge_id,
        "n_steps": n_steps,
        "mean_rel_err": mean_rel_err,
        "max_rel_err": max_rel_err,
        "threshold": PASS_THRESHOLD,
        "pass": pass_flag,
        "absorbed": absorbed,
        "artifact": os.path.basename(out_path),
        "timings_sec": {
            "fetch": round(t_fetch, 3),
            "bridge_lambda_d": round(t_bridge, 3),
            "hexa_lambda_d": round(t_hexa, 3),
        },
        "python_version": py_ver,
    }
    sys.stderr.write(
        "UFO_VERIFY_MEASURED_ORACLE_RESULT "
        + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
