#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
zlotnick_ode.py — independent Zlotnick-style cage-assembly ODE substrate

Pure-stdlib mean-field Zlotnick 1999 capsid-assembly ODE with explicit Euler
integration. Cuts hexa-bio's virocapsid axis loose from the shared
`~/core/nexus/sim_bridge/weave/` ODE so the empirical sandbox has its own
in-tree substrate (closes CLOSURE_RESIDUAL_BACKLOG.md §A2.1 / cycle-28+
tag "sandbox 평준화").

## Model

N capsomers per shell (σ(6)=12 pentamers for T=1 — see HEXA-VIROCAPSID.md
+ .roadmap.virocapsid). Mean-field species:

  M           — free monomer (capsomer) concentration
  I_k         — partial-shell intermediate with k capsomers attached (1 ≤ k ≤ N-1)
  C           — completed shell (sink — no reverse-back-to-I_{N-1})

Reactions (k_a = bimolecular association rate constant; k_d = unimolecular
dissociation rate constant; dimensionless concentrations, [M(0)] = 1.0):

  2 M    → I_2       at rate (k_a / 2) * M^2          (nucleation)
  M + I_k → I_{k+1}  at rate k_a * M * I_k            (1 < k < N-1, growth)
  M + I_{N-1} → C    at rate k_a * M * I_{N-1}        (capping)
  I_k → I_{k-1} + M  at rate k_d * I_k                (reverse; 2 ≤ k ≤ N-1)
  (no I_N reverse — C is absorbing per Zlotnick original)

Mass conservation invariant (checked by selftest, not assumed):
  M(t) + Σ k·I_k(t) + N·C(t) = M(0) = 1.0,   ∀t

## raw_91 honest C3 disclosure

What this script measures:
  - Numerical integration of the Zlotnick mean-field ODE with the chosen
    rate constants, capsomer count N, initial monomer M0, and end time
    t_end. Returns the yield fraction `N·C / M0` at t_end.
  - Determinism: identical inputs → byte-identical floating outputs (no
    randomness, fixed dt, no thread-dependent reductions).

What this script does NOT measure / claim:
  - That the chosen rate constants reproduce any specific experimental
    yield. **Calibrated rate constants for "T=1/T=3/T=4 yield ≥ 0.85"
    are the responsibility of `virocapsid/module/calibration.hexa` and
    `virocapsid/module/multi_t_calibration.hexa`**, not this script.
    This script is a *substrate* — a clean, deterministic ODE — and a
    smoke gate (yield ∈ [0,1], mass conserves, non-trivial dynamics).
  - Molecular-dynamics fidelity. This is mean-field, ignores spatial /
    diffusion effects, treats all capsomers as identical, and uses
    explicit Euler with a fixed dt — for very high k_a or near-zero k_d
    the step may need to shrink (the selftest's dt = 1e-3 is calibrated
    for the default rate-constant range, not the stiff limit).
  - The N=12 default matches σ(6)=12 pentamers for T=1; for T=3 / T=4
    Caspar-Klug counts differ (12 pent + 20 hex / 12 pent + 30 hex
    respectively). The T-label here is a parameter alias; for true
    T=3/T=4 you'd extend with two-species (pent + hex) kinetics —
    that's V-R2 cycle-30+ stretch territory, intentionally out of
    scope here.

CLI:
  python3 zlotnick_ode.py --selftest      # smoke test, exits 0 on PASS
  python3 zlotnick_ode.py --t-number 1    # run with T=1 defaults, print JSON
  python3 zlotnick_ode.py --t-number 7    # T=7/13/21 = V-R2 stretch (B4.1)
  python3 zlotnick_ode.py --emit-json     # JSON output to stdout

T-numbers: {1, 3, 4} = A2.1 baseline (cycle-30+++ CLOSED 2026-05-12);
           {7, 13, 21} = B4.1 V-R2 stretch (cycle-30+++ CLOSED 2026-05-12).
For T=7/13/21 the pentamer-level N=12 cascade still applies (σ(6)=12
invariant pentameric vertices); rate constants are T-scaled per the
T_DEFAULTS comment. raw_91 honest C3: T=21 rate-constants are
extrapolation from T=13 trend, not wet-lab calibration.

Sentinel: `__VIROCAPSID_ZLOTNICK_ODE_CLI__ PASS`

Cross-refs:
  - CLOSURE_RESIDUAL_BACKLOG.md §A2.1 (T=1/3/4 baseline) + §B4.1 (T=7/13/21)
  - AXIS_CLOSURE_PLAN.md L166 (this row's ✅ flip)
  - .roadmap.virocapsid (closure-condition row + V-R2 stretch)
"""
from __future__ import annotations
import argparse
import io
import json
import math
import sys
from typing import Dict, List, Tuple


# ---- canonical T-number defaults ------------------------------------------
# Rate constants picked so the default selftest produces non-trivial dynamics
# (yield clearly > 0 and clearly < 1 within t_end), not to match any specific
# experiment. Calibration for actual experimental yields is calibration.hexa's
# responsibility.
#
# T=1/T=3/T=4 baseline (cycle-30+++ closure A2.1) — DO NOT MODIFY.
# T=7/T=13/T=21 extension (cycle-30+++ closure B4.1, V-R2 stretch) —
# parameters chosen via:
#   - T=7 (HK97-class, 420 subunits): slower nucleation than T=4; k_a halved
#     and k_d doubled, t_end extended to 120 to allow comparable C-yield.
#     Reference: Endres & Zlotnick 2002 (HK97 kinetics); Hagan & Elrad 2010
#     "Concentration dependence of viral capsid assembly kinetics" PMC2849049
#     — they note nucleation rate scales inversely with cage size.
#   - T=13 (bluetongue / reovirus, 780 trimers / VP3-templated): scaffold-
#     guided, even slower stochastic nucleation. k_a halved again, k_d
#     bumped to 1.5, t_end=180. Reference: Roy 2014 / Patel & Roy 2014
#     "Bluetongue Virus Capsid Assembly and Maturation" PMC4147694 — VP3
#     scaffold + 260 VP7 trimers, stepwise.
#   - T=21 (uncommon — chlorovirus / phycodnavirus-class extrapolation):
#     no T=21 in icosahedral series proper (T ∈ {1,3,4,7,12,13,16,19,21,...}
#     per Caspar-Klug h²+hk+k² with (h,k)=(4,1) → T=21). No standard wet-lab
#     T=21 rate-constant literature exists. **Extrapolation** from T=13
#     trend (k_a -> k_a / 1.5, k_d -> 2.0, t_end -> 240).
#     raw_91 honest C3: extrapolation, not empirically calibrated; the
#     pentamer-level N=12 model is invariant in σ(6)=12 across T but does
#     NOT capture T-specific hexamer dynamics or scaffold templating —
#     these are V-R2 stretch territory. The smoke selftest validates the
#     substrate (yield∈[0,1] + mass conserves + non-trivial dynamics +
#     determinism), not T=21-specific kinetics.
#
# Mass conservation invariant (M(t) + Σ k·I_k + N·C = M0) is independent of
# the rate constants by construction of the explicit-Euler step — it holds
# at machine epsilon for any (k_a, k_d, t_end, dt) within the stiff-stability
# envelope (dt < ~2/(k_a * M0) for the explicit method).
T_DEFAULTS: Dict[int, Dict[str, float]] = {
    # Defaults sized so the smoke selftest sees nonzero C within t_end. With
    # N=12 sequential bimolecular steps the per-step rate scales as k_a * <I>
    # and <I> ≈ M0/N, so total traversal time ~ (N-1)/(k_a * M0 / N). For
    # M0=1.0, N=12 we need k_a ≳ N² / t_end ~ 144/60 ≈ 2.4 just to traverse;
    # k_a ≳ 50 gives several traversal-times worth of headroom over t_end=60.
    # (Calibration to specific experimental yields is calibration.hexa's job.)
    1:  {"N": 12, "M0": 1.0, "k_assoc": 50.0, "k_diss": 0.50, "t_end":  60.0, "dt": 1e-3},
    3:  {"N": 12, "M0": 1.0, "k_assoc": 50.0, "k_diss": 0.50, "t_end":  60.0, "dt": 1e-3},
    4:  {"N": 12, "M0": 1.0, "k_assoc": 50.0, "k_diss": 0.50, "t_end":  60.0, "dt": 1e-3},
    # V-R2 stretch: T=7 / T=13 / T=21
    7:  {"N": 12, "M0": 1.0, "k_assoc": 25.0, "k_diss": 1.00, "t_end": 120.0, "dt": 1e-3},
    13: {"N": 12, "M0": 1.0, "k_assoc": 12.0, "k_diss": 1.50, "t_end": 180.0, "dt": 1e-3},
    21: {"N": 12, "M0": 1.0, "k_assoc":  8.0, "k_diss": 2.00, "t_end": 240.0, "dt": 1e-3},
}


# ---- ODE step ------------------------------------------------------------
def _zlotnick_step(state: List[float], k_a: float, k_d: float, dt: float) -> List[float]:
    """One explicit-Euler step. state = [M, I_2, I_3, ..., I_{N-1}, C], length = N."""
    N = len(state)  # state has M + (N-2) intermediates + C, total length N
    # index map: state[0]=M, state[1]=I_2, ..., state[N-2]=I_{N-1}, state[N-1]=C
    M = state[0]
    I = state[1:N - 1] if N >= 3 else []   # I_2 .. I_{N-2}  (may be empty for tiny N)
    I_last = state[N - 2] if N >= 2 else 0.0  # I_{N-1} (capping reactant)
    C = state[N - 1]

    new = [0.0] * len(state)

    # Nucleation 2M → I_2:  rate = (k_a/2) * M^2
    r_nuc = 0.5 * k_a * M * M

    # Capping M + I_{N-1} → C:  rate = k_a * M * I_{N-1}
    r_cap = k_a * M * I_last

    # Reverse rates per intermediate
    # We'll compute growth/decay flow per-bin then assemble dM
    # Internal growth rates (rate from I_k to I_{k+1}): r_grow[k] = k_a * M * I_k
    # Internal decay rates (rate from I_{k+1} to I_k via reverse): r_back[k] = k_d * I_{k+1}
    # All intermediates I_2..I_{N-1}
    intermediates = state[1:N - 1]  # I_2..I_{N-1}, length = N-2 (excludes M at [0] and C at [N-1])
    n_int = len(intermediates)

    # Growth out of I_k toward I_{k+1} (for k = 2..N-2): consumed by M + I_k → I_{k+1}
    # Last intermediate I_{N-1} growth is the capping reaction r_cap.
    r_grow: List[float] = []
    for k_idx, I_k in enumerate(intermediates):
        if k_idx == n_int - 1:
            # I_{N-1} growth = r_cap; already accounted
            r_grow.append(r_cap)
        else:
            r_grow.append(k_a * M * I_k)

    # Reverse rate of I_k → I_{k-1} + M (for k = 2..N-1)
    r_back = [k_d * I_k for I_k in intermediates]
    # Note: r_back[0] is reverse of I_2 → I_1 + M, but I_1 is unstable / not tracked
    # (nucleation creates I_2 directly). So r_back[0] dissociates I_2 → 2M.

    # ---- dM/dt ----
    dM = 0.0
    # nucleation consumes 2 M
    dM -= 2.0 * r_nuc
    # each growth consumes 1 M
    dM -= sum(r_grow)
    # nucleation reverse (I_2 → 2M) gives back 2 M
    dM += 2.0 * r_back[0]
    # other reverses (I_k → I_{k-1} + M for k ≥ 3) each give back 1 M
    dM += sum(r_back[1:])

    new[0] = M + dt * dM

    # ---- dI_k/dt ----
    for k_idx in range(n_int):
        # k = k_idx + 2 in original numbering
        dI = 0.0
        # +nucleation if this is I_2 (k_idx == 0)
        if k_idx == 0:
            dI += r_nuc
        else:
            # +growth FROM previous intermediate
            dI += r_grow[k_idx - 1]
        # -growth OUT to next intermediate (or to C if last)
        dI -= r_grow[k_idx]
        # -reverse of this bin
        dI -= r_back[k_idx]
        # +reverse FROM next bin (I_{k+1} → I_k + M)
        if k_idx + 1 < n_int:
            dI += r_back[k_idx + 1]
        new[1 + k_idx] = intermediates[k_idx] + dt * dI

    # ---- dC/dt ----
    new[N - 1] = C + dt * r_cap

    # Clamp negatives (Euler can drift slightly negative on near-zero bins)
    for i in range(len(new)):
        if new[i] < 0.0 and new[i] > -1e-12:
            new[i] = 0.0
    return new


def run(N: int, M0: float, k_assoc: float, k_diss: float, t_end: float, dt: float,
        snapshot_count: int = 10) -> Dict[str, float]:
    """Integrate the Zlotnick ODE. Return summary dict."""
    if N < 3:
        raise ValueError(f"N must be >= 3 (smallest non-trivial shell); got {N}")
    # state = [M, I_2, I_3, ..., I_{N-1}, C]  → length N
    state = [0.0] * N
    state[0] = M0

    n_steps = int(round(t_end / dt))
    snap_every = max(1, n_steps // snapshot_count)
    trajectory: List[Tuple[float, float, float]] = []  # (t, M, C)

    for step in range(n_steps):
        if step % snap_every == 0:
            trajectory.append((round(step * dt, 6), state[0], state[N - 1]))
        state = _zlotnick_step(state, k_assoc, k_diss, dt)
    # final snapshot
    trajectory.append((round(n_steps * dt, 6), state[0], state[N - 1]))

    M_final = state[0]
    intermediates_total = sum(k * state[k - 1] for k in range(2, N))  # mass in intermediates
    C_final = state[N - 1]

    mass_in = M0
    mass_out = M_final + intermediates_total + N * C_final
    mass_conservation_error = abs(mass_out - mass_in)

    yield_frac = (N * C_final) / M0  # fraction of M0 mass locked in complete shells

    return {
        "N": N,
        "M0": M0,
        "k_assoc": k_assoc,
        "k_diss": k_diss,
        "t_end": t_end,
        "dt": dt,
        "n_steps": n_steps,
        "M_final": M_final,
        "intermediates_mass": intermediates_total,
        "C_final": C_final,
        "yield_fraction": yield_frac,
        "mass_conservation_error": mass_conservation_error,
        "trajectory": trajectory,
    }


# ---- selftest -------------------------------------------------------------
def selftest() -> int:
    print("zlotnick_ode — virocapsid independent Zlotnick mean-field ODE substrate\n", flush=True)
    passes = 0
    fails = 0

    def check(label: str, ok: bool, detail: str = "") -> None:
        nonlocal passes, fails
        status = "[PASS]" if ok else "[FAIL]"
        print(f"  {status} {label}" + (f"  ({detail})" if detail else ""))
        if ok:
            passes += 1
        else:
            fails += 1

    # Run for T=1, T=3, T=4, T=7, T=13, T=21 with their default parameter sets.
    # T=1/3/4 = cycle-30+++ A2.1 baseline; T=7/13/21 = cycle-30+++ B4.1 V-R2 stretch.
    results = {}
    for T in (1, 3, 4, 7, 13, 21):
        params = T_DEFAULTS[T]
        r = run(N=params["N"], M0=params["M0"],
                k_assoc=params["k_assoc"], k_diss=params["k_diss"],
                t_end=params["t_end"], dt=params["dt"])
        results[T] = r
        print(f"\n  --- T={T}  N={r['N']}  k_a={r['k_assoc']}  k_d={r['k_diss']}  t_end={r['t_end']} ---")
        print(f"      M_final = {r['M_final']:.6f}")
        print(f"      intermediates mass = {r['intermediates_mass']:.6f}")
        print(f"      C_final = {r['C_final']:.6f}")
        print(f"      yield_fraction = {r['yield_fraction']:.6f}")
        print(f"      mass_conservation_error = {r['mass_conservation_error']:.3e}")

        # Smoke checks
        check(f"T={T} yield ∈ [0,1]",
              0.0 <= r["yield_fraction"] <= 1.0,
              f"yield={r['yield_fraction']:.4f}")
        check(f"T={T} mass conservation < 1e-6",
              r["mass_conservation_error"] < 1e-6,
              f"err={r['mass_conservation_error']:.3e}")
        check(f"T={T} non-trivial dynamics (M consumed)",
              r["M_final"] < params["M0"] * 0.99,
              f"M_final/M0={r['M_final']/params['M0']:.4f}")
        check(f"T={T} non-trivial dynamics (some C formed)",
              r["C_final"] > 1e-6,
              f"C_final={r['C_final']:.3e}")

    # Determinism: re-run T=1 (baseline) and T=21 (V-R2 stretch / longest
    # integration) and compare yield/M/C exactly. T=21 covers the longest
    # t_end (240.0) so it's the strictest reproducibility check.
    for T_det in (1, 21):
        print(f"\n  --- determinism (T={T_det} byte-identical re-run) ---")
        p = T_DEFAULTS[T_det]
        r2 = run(N=p["N"], M0=p["M0"], k_assoc=p["k_assoc"], k_diss=p["k_diss"],
                 t_end=p["t_end"], dt=p["dt"])
        check(f"determinism T={T_det}: M_final identical",
              results[T_det]["M_final"] == r2["M_final"],
              f"Δ={abs(results[T_det]['M_final'] - r2['M_final']):.3e}")
        check(f"determinism T={T_det}: C_final identical",
              results[T_det]["C_final"] == r2["C_final"],
              f"Δ={abs(results[T_det]['C_final'] - r2['C_final']):.3e}")
        check(f"determinism T={T_det}: trajectory identical",
              results[T_det]["trajectory"] == r2["trajectory"],
              "tuple-equal")

    total = passes + fails
    print(f"\n  Summary: {passes}/{total} checks PASS")
    if fails == 0:
        print("\n__VIROCAPSID_ZLOTNICK_ODE_CLI__ PASS")
        return 0
    else:
        print("\n__VIROCAPSID_ZLOTNICK_ODE_CLI__ FAIL")
        return 1


# ---- CLI -----------------------------------------------------------------
def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Zlotnick capsid-assembly ODE substrate.")
    parser.add_argument("--selftest", action="store_true", help="Run T=1/3/4/7/13/21 smoke + determinism check.")
    parser.add_argument("--t-number", type=int, choices=[1, 3, 4, 7, 13, 21], help="Run with T-number default parameter set.")
    parser.add_argument("--n", type=int, help="Capsomer count per shell (default 12 for T=1).")
    parser.add_argument("--m0", type=float, default=1.0, help="Initial monomer concentration.")
    parser.add_argument("--k-assoc", type=float, help="Bimolecular association rate constant.")
    parser.add_argument("--k-diss", type=float, help="Unimolecular dissociation rate constant.")
    parser.add_argument("--t-end", type=float, help="End time.")
    parser.add_argument("--dt", type=float, default=1e-3, help="Euler step size.")
    parser.add_argument("--emit-json", action="store_true", help="JSON output to stdout.")
    args = parser.parse_args(argv)

    if args.selftest:
        return selftest()

    T = args.t_number or 1
    p = dict(T_DEFAULTS[T])
    if args.n is not None:
        p["N"] = args.n
    if args.k_assoc is not None:
        p["k_assoc"] = args.k_assoc
    if args.k_diss is not None:
        p["k_diss"] = args.k_diss
    if args.t_end is not None:
        p["t_end"] = args.t_end
    p["M0"] = args.m0
    p["dt"] = args.dt

    r = run(N=p["N"], M0=p["M0"], k_assoc=p["k_assoc"], k_diss=p["k_diss"],
            t_end=p["t_end"], dt=p["dt"])

    if args.emit_json:
        sys.stdout.write(json.dumps(r, indent=2) + "\n")
    else:
        print(f"Zlotnick ODE — T={T}  N={r['N']}  M0={r['M0']}  k_a={r['k_assoc']}  k_d={r['k_diss']}  t_end={r['t_end']}")
        print(f"  M_final           = {r['M_final']:.6f}")
        print(f"  intermediates_mass= {r['intermediates_mass']:.6f}")
        print(f"  C_final           = {r['C_final']:.6f}")
        print(f"  yield_fraction    = {r['yield_fraction']:.6f}")
        print(f"  mass_conservation_error = {r['mass_conservation_error']:.3e}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
