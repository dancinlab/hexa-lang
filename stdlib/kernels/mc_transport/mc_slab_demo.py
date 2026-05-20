# mc_slab_demo.py — D80 g_hexa_only pilot, Python parity oracle
#
# Companion to `mc_slab_demo.hexa`. THIS Python file is NOT the
# canonical implementation — it is the cross-check oracle for the
# hexa-native version. Both files implement THE SAME LCG (Numerical
# Recipes a=1664525, c=1013904223, m=2^32), THE SAME free-flight /
# collision / scatter sampling, and SHOULD produce bit-identical
# tallies for matching (seed, N, L, sigma_t, sigma_s, sigma_a, source)
# inputs — see `mc_slab_demo_test.py` and the hexa companion test.
#
# Layer (ABSORPTION.md ① / demiurge design.md D72):
#   ①a kernel — THIS FILE + `mc_slab_demo.hexa`. Domain-agnostic.
#                No OpenMC, no Geant4, no nuclear-data download — a
#                single-energy-group 1-D slab analytic test problem
#                that runs on pure-Python / pure-hexa primitives.
#   ①b adapter — none yet. A future adapter under `stdlib/nuclear/`
#                would supply real cross-sections and replace the
#                analytic single-group abstraction with energy-
#                dependent ENDF data + OpenMC parity once OpenMC is
#                actually installable on the host pool (Track D
#                κ-65 blocked on macOS arm64 + Linux pool unreachable
#                as of 2026-05-20).
#
# CLEAN-ROOM PROVENANCE
#   No OpenMC code, no Geant4 code. The algorithm is the standard
#   1-D slab Monte-Carlo transport recipe (Duderstadt & Hamilton
#   "Nuclear Reactor Analysis" §4.5; Lewis & Miller "Computational
#   Methods of Neutron Transport" §5.2). The analytic oracle for a
#   pure absorber (Sigma_s = 0) is the Beer-Lambert law
#   T = exp(-Sigma_t * L) — direct consequence of exponential
#   free-flight sampling, no Monte Carlo even required.
#
# HONESTY (g3 — non-negotiable):
#   * This is a PILOT for the D80 hexa-native port pattern. It is
#     NOT a measured-parity tally — the cross-section numbers below
#     are illustrative single-group constants, not real nuclide data.
#     `absorbed = false` at any demiurge cell consuming this kernel.
#   * energy+verify, fusion+verify, reactor+verify etc. still need
#     OpenMC for measured-parity numbers — this pilot only proves
#     the port pattern works end-to-end without OpenMC installed.
#   * The Monte Carlo statistical uncertainty for N samples is
#     ~1/sqrt(N) for a Bernoulli tally; with N=1e6 we expect ~0.1 %
#     std on T. The pilot's parity tolerance for hexa-vs-python is
#     tighter (we use the SAME RNG seed, so the two runs are
#     bit-identical modulo float operation order — agreement should
#     be at machine epsilon, NOT 1/sqrt(N)).

import math

# ── LCG constants — matches stdlib/core/math/rng.hexa ───────────────
LCG_A = 1664525
LCG_C = 1013904223
LCG_MASK = 0xFFFFFFFF
LCG_TWO32 = 4294967296.0


def lcg_next(state: int) -> int:
    """Single-step Numerical-Recipes LCG; mirrors `stdlib/core/math/
    rng.hexa::lcg_next`. State stays in [0, 2^32)."""
    return (LCG_A * state + LCG_C) & LCG_MASK


def lcg_float01(state: int):
    """Returns (new_state, float in [0, 1)); mirrors
    `stdlib/core/math/rng.hexa::lcg_float01`."""
    nxt = lcg_next(state)
    return nxt, nxt / LCG_TWO32


def run_slab(L: float,
             sigma_t: float,
             sigma_s: float,
             sigma_a: float,
             n_particles: int,
             seed: int,
             forward_beam: bool = True) -> dict:
    """1-D slab Monte-Carlo neutron transport tally.

    Geometry: uniform slab x ∈ [0, L]. Source at x=0.
    Cross-sections: single energy group; Σ_t = Σ_s + Σ_a must hold
    (the caller is responsible for consistent constants; the kernel
    does NOT silently re-normalise).
    Source: monoenergetic. If forward_beam=True, all neutrons start
    with μ = cos(θ) = 1 (analytic check uses this; pure-absorber case
    gives T = exp(-Σ_t · L) exactly in the infinite-sample limit).
    If False, μ ~ U(0, 1] — isotropic into the forward hemisphere
    (full isotropic source's backward half would immediately leak
    through the x=0 vacuum boundary, so we exclude it at sampling
    time rather than wasting random draws).

    Scattering: isotropic each collision — new μ ~ U(-1, 1).

    Tallies:
      T = transmission probability (fraction that exit at x ≥ L)
      A = absorption probability (fraction absorbed in 0 < x < L)
      R = reflection / leakage at x=0 probability
      mean_collisions = mean collisions per neutron (any history)
    """
    if sigma_t <= 0.0:
        raise ValueError(f"sigma_t must be positive, got {sigma_t}")
    if sigma_s < 0.0 or sigma_a < 0.0:
        raise ValueError(
            f"sigma_s ({sigma_s}) and sigma_a ({sigma_a}) "
            f"must be non-negative")
    # g3: do NOT silently re-normalise. Check the consistency.
    if abs((sigma_s + sigma_a) - sigma_t) > 1e-12 * sigma_t:
        raise ValueError(
            f"sigma_s + sigma_a ({sigma_s + sigma_a}) "
            f"!= sigma_t ({sigma_t}) — caller must supply "
            f"consistent cross-sections")
    if n_particles < 1:
        raise ValueError(f"n_particles must be >= 1, got {n_particles}")

    p_abs = sigma_a / sigma_t          # collision -> absorb probability
    state = seed & LCG_MASK

    n_trans = 0
    n_abs = 0
    n_refl = 0
    total_collisions = 0

    for _ in range(n_particles):
        # ── sample initial direction ────────────────────────────────
        if forward_beam:
            mu = 1.0
        else:
            state, u = lcg_float01(state)
            # μ ∈ (0, 1] — isotropic into forward hemisphere
            mu = u
            if mu < 1e-12:
                mu = 1e-12   # avoid divide-by-zero in pathological draw
        x = 0.0
        collisions = 0
        alive = True
        while alive:
            # ── sample free flight ──────────────────────────────────
            state, u = lcg_float01(state)
            # u ∈ [0, 1); -log(0) = inf, so guard.
            if u < 1e-300:
                u = 1e-300
            s = -math.log(u) / sigma_t
            x = x + s * mu

            # ── boundary checks ─────────────────────────────────────
            if x >= L:
                n_trans += 1
                alive = False
                break
            if x <= 0.0:
                n_refl += 1
                alive = False
                break

            # ── collision: absorb or scatter ────────────────────────
            collisions += 1
            state, u = lcg_float01(state)
            if u < p_abs:
                n_abs += 1
                alive = False
                break
            # scatter: new μ ~ U(-1, 1) — isotropic
            state, u = lcg_float01(state)
            mu = 2.0 * u - 1.0
            # guard against the cos = 0 edge (neutron stuck on plane)
            if -1e-12 < mu < 1e-12:
                mu = 1e-12 if mu >= 0.0 else -1e-12
        total_collisions += collisions

    n_f = float(n_particles)
    return {
        "n_particles": n_particles,
        "L_cm": L,
        "sigma_t": sigma_t,
        "sigma_s": sigma_s,
        "sigma_a": sigma_a,
        "seed": seed,
        "forward_beam": bool(forward_beam),
        "transmission": n_trans / n_f,
        "absorption": n_abs / n_f,
        "reflection": n_refl / n_f,
        "mean_collisions": total_collisions / n_f,
        "n_trans": n_trans,
        "n_abs": n_abs,
        "n_refl": n_refl,
        "total_collisions": total_collisions,
    }


def analytic_transmission_beam_pure_absorber(L: float,
                                             sigma_t: float) -> float:
    """Analytic transmission for a beam source through a pure
    absorber: T = exp(-Σ_t · L). Direct from exponential free-flight
    sampling — Beer-Lambert law. The Monte-Carlo run with sigma_s=0
    and forward_beam=True should agree to ~1/sqrt(N) statistical
    noise (5% relative for N=1e6 if T ≈ exp(-Σ_t·L) ≈ 0.0067 — note
    the relative-error standard deviation on a Bernoulli is
    sqrt((1-T)/(N·T)) which grows for small T)."""
    return math.exp(-sigma_t * L)


if __name__ == "__main__":
    # Sanity run — pure absorber, beam source. With L=1.0 cm,
    # Σ_t=1.0, this gives T_analytic = e^-1 ≈ 0.3679.
    res = run_slab(L=1.0, sigma_t=1.0, sigma_s=0.0, sigma_a=1.0,
                   n_particles=1_000_000, seed=12345, forward_beam=True)
    t_anal = analytic_transmission_beam_pure_absorber(1.0, 1.0)
    print(f"T_mc       = {res['transmission']:.12f}")
    print(f"T_analytic = {t_anal:.12f}")
    print(f"rel_err    = {abs(res['transmission'] - t_anal) / t_anal:.3e}")
    print(f"A          = {res['absorption']:.12f}")
    print(f"R          = {res['reflection']:.12f}")
    print(f"mean_coll  = {res['mean_collisions']:.6f}")
