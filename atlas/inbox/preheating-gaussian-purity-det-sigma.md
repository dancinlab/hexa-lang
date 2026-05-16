# preheating-gaussian-purity-det-sigma

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Gondret et al. 2025 cold-atom analog of cosmological
preheating (arXiv:2506.22024 / Phys. Rev. Lett. **135**, 240603
(2025)), a **pure vacuum-seeded two-mode squeezed state** has a
covariance matrix `σ` whose determinant is the exact constant

    det σ = 1/16   (ħ = 1 convention, n_th = 0)

i.e. `1/4 per mode` for a two-mode Gaussian pure state. The
two-mode-squeezed vacuum (TMSV) is a pure Gaussian state; for a
single mode the vacuum covariance is `diag(1/2, 1/2)` with
`det σ_1mode = 1/4`, and a pure two-mode Gaussian state factorises
its symplectic invariant as

    det σ = (det σ per mode)² = (1/4)² = 1/16.

Equivalently, via the canonical-commutator invariant `|u|²−|v|²=1`
(see sibling atom `preheating-bogoliubov-canonical-commutator`):

    det σ = (|u_k|² − |v_k|²)⁴ / 16 = 1⁴ / 16 = 1/16.

This is the **Gaussian-purity cross-check**: a pure Gaussian state
saturates the symplectic uncertainty bound, so `det σ` is pinned to
its minimal value `1/16` (two modes, ħ=1) — independent of the
squeezing parameter `r` (squeezing redistributes variance between
quadratures but preserves the symplectic volume `det σ` exactly).
It is the load-bearing identity behind the module's selftest
purity invariant.

## Hexa-native verification

The sim-universe `preheating-analog/module/preheating.hexa`
selftest emits the invariant directly:

    Gaussian purity : det σ = 0.062500 (== 1/16 = 0.062500; OK)

with sentinel:

    __SIM_UNIVERSE_PREHEATING__ PASS mode=selftest nk=0.391 r=...
        EN=... norm_drift=0.000000

Build + run command:

    bash state/ubu-build.sh \
        preheating-analog/module/preheating.hexa \
        preheating_bin --selftest

The atlas-side verifier closes this as the **closed-form rational
identity** `1/16 = 0.0625` AND the squeezing-invariance check:
compute `det σ = (|u_k|²−|v_k|²)⁴/16` at several squeezing values
`r` (equivalently several `|v_k|` with `|u_k|² = 1+|v_k|²` from the
canonical commutator) and confirm it equals `1/16` exactly at every
`r` (squeezing-independent — the symplectic volume is invariant
under the BdG flow).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — `1/16` is an exact
  rational; `det σ = W⁴/16` with `W = |u|²−|v|² = 1` (the canonical
  commutator) is integer/rational-exact, no transcendental
  involved; the squeezing-independence sweep is integer-`r` exact).
- **Axis:** §3 PHYS (Gaussian quantum optics / two-mode squeezed
  vacuum) · cross-link §2 MATH (symplectic-invariant rational
  identity) · §6 COSMO (preheating analog).
- **Real-limit anchor (`g3`):**
  - **Gondret et al.**, **Phys. Rev. Lett. 135, 240603 (2025)** /
    arXiv:2506.22024, two-mode-squeezing model eq:tmsth (the
    homogeneous-background TMSV state with `⟨â_+ â_-†⟩ = 0`).
  - **Heisenberg uncertainty / symplectic minimum** — a pure
    Gaussian state saturates `det σ ≥ (ħ/2)^{2N}`; for `N = 2`
    modes, `ħ = 1`, the minimum (purity) value is exactly
    `(1/2)⁴ = 1/16`.
  - **Simon 2000 / Adesso-Illuminati 2007** — TMSV purity and
    log-negativity for pure two-mode Gaussian states; `det σ`
    symplectic invariant.
  - [compiler invariant — `1/16` is an exact dyadic rational; the
    identity is closed in ℚ, no floating-point tolerance needed].
- **Provenance:** sim-universe commit (preheating-analog landing) ·
  `preheating-analog/module/preheating.hexa` (det-σ purity
  cross-check) · AGENTS.tape `@D g14` · `@X x_gondret_preheating`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_mode_count`** — `det σ = (1/2)^{2N}` for `N` modes
   (ħ=1). For ONE mode `det σ = 1/4`; for TWO modes `1/16`; for
   THREE `1/64`. If the verifier reports `1/4` (single-mode
   confusion) instead of `1/16` for the two-mode TMSV, FIRES.
   Verifier asserts the two-mode value `= 0.0625` exactly.
2. **`F2_squeezing_dependent`** — purity ⇒ `det σ` is **independent
   of the squeezing `r`** (symplectic-volume invariant). If the
   verifier finds `det σ` varying with `r` (e.g. `det σ = cosh²(2r)
   /16`, a mixed-state-like error), the state is not pure / the
   formula is wrong — FIRES. Verifier sweeps `r` (via several
   `|v_k|` with `|u_k|²=1+|v_k|²`) and asserts `det σ = 1/16` at
   every `r`.
3. **`F3_hbar_convention`** — `det σ = 1/16` uses `ħ = 1`,
   `n_th = 0`. With the `ħ/2 = 1` convention `det σ = 1` (per-mode
   1). If the verifier mixes conventions and reports `1` or `1/256`,
   the convention is inconsistent — FIRES. Verifier fixes ħ=1,
   n_th=0 and asserts `0.0625`.
4. **`F4_thermal_seed`** — a thermal-seeded (`n_th > 0`) state is
   MIXED, with `det σ = (2n_th+1)⁴/16 > 1/16` (purity lost). The
   atom is **specifically** the *pure vacuum-seeded* (`n_th = 0`)
   case. If the verifier silently uses `n_th = 0.18` (the paper's
   measured thermal occupation) and still reports `1/16`, the
   thermal correction was dropped — FIRES. Verifier asserts the
   `n_th = 0` vacuum seed gives exactly `1/16` and that
   `n_th = 0.18` would give `> 1/16` (distinguishes the cases).
5. **`F5_canonical_commutator_broken`** — `det σ = W⁴/16` with
   `W = |u|²−|v|² = 1`. If the BdG flow did NOT conserve `W` (see
   sibling atom), `det σ` would drift away from `1/16`. Verifier
   asserts `W = 1` first, then `det σ = W⁴/16 = 1/16`; a `W ≠ 1`
   FIRES (this couples the purity to the canonical-commutator atom).
6. **`F6_not_exact_rational`** — `1/16` is an exact dyadic
   rational (`0.0625`, terminating in binary float). If the
   verifier reports `0.062499...` / `0.06251` (a floating-point
   accumulation error suggesting the value is being *computed* via
   a transcendental path rather than the exact rational identity),
   the closed-form claim is undermined — FIRES. Verifier asserts
   bit-exact `0.0625`.

## Honest C3

This atom is **specifically** the *pure vacuum-seeded two-mode
squeezed state* purity `det σ = 1/16`. It holds ONLY for the pure
Gaussian (`n_th = 0`, linear-Bogoliubov) regime. The paper's
measured initial thermal occupation `n_th = 0.18(8)` makes the
*experimental* state weakly mixed (`det σ > 1/16`); the module's
selftest uses the idealised vacuum seed for the purity cross-check
and does NOT claim the experiment is exactly pure. The late-time
nonlinear regime (paper Fig. 3, `t > 3 ms`) breaks Gaussianity
entirely and is OUTSIDE the linear theory (per `@D g14` honest
scope). The atom absorbs the exact pure-TMSV symplectic-volume
identity only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `preheating-analog/` (Tier-A2).
Paper: Gondret et al., Phys. Rev. Lett. 135, 240603 (2025) /
arXiv:2506.22024. AGENTS.tape `@D g14` / `@X x_gondret_preheating`.
