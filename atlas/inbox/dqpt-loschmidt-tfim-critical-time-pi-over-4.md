# dqpt-loschmidt-tfim-critical-time-pi-over-4

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the transverse-field Ising chain (TFIM) dynamical quantum
phase transition (Heyl, Polkovnikov, Kehrein, *Phys. Rev. Lett.*
**110**, 135704 (2013), Eq. 4–5; preprint arXiv:1206.2505), a
quench `g₀ → g₁` *across* the critical point `g_c = 1` makes the
rate function `λ_∞(t) = −(1/2π)∫₀^π ln[1 − sin²(2Δ_k) sin²(ε₁(k)t)]
dk` **non-analytic** at the critical times

    t*_n = t* (n + ½) ,   n = 0,1,2,…   with   t* = π / ε_{g₁}(k*)

where `k*` is the Fisher-zero mode `cos k* = (1 + g₀g₁)/(g₀ + g₁)`
and `ε_g(k) = 2√(1 + g² − 2g cos k)`.

For the module's **unambiguous selftest quench in the analytic
limit** `g₀ → ∞ , g₁ → 0` (deep paramagnet → classical Ising
point):

    cos k* = (1 + g₀g₁)/(g₀+g₁) → 0          ⇒  **k* = π/2**
    ε_{g₁=0}(k*) = 2√(1 + 0 − 0) = 2
    t* = π / ε_{g₁}(k*) = π / 2
    **t*₀ = t* · (0 + ½) = π/4 ≈ 0.7853981633974483**

So the first (and fundamental) DQPT cusp in `λ_∞(t)` is at the
**closed form `t*₀ = π/4`**. The full ladder is
`t*_n = (π/2)(n+½) = π/4, 3π/4, 5π/4, …`.

## Hexa-native verification

The sim-universe `dqpt-loschmidt/module/dqpt.hexa` selftest
(quench `g₀=50 → g₁=0`, analytic `k*=π/2`, `t*=π/2`) emits the
invariant directly:

    (b) closed-form kink at analytic t*₀ = t*/2 :
        d²(λ_∞)/dt² spikes ≥5× off-cusp reference (OK)
    (d) control (no DQPT) g₀=0.4→g₁=0.8 : λ_∞ smooth (OK)

with sentinel:

    __SIM_UNIVERSE_DQPT__ PASS ... mode=selftest
        norm_drift=...

Build + run command:

    bash state/ubu-build.sh \
        dqpt-loschmidt/module/dqpt.hexa dqpt_bin --selftest

(or `./state/dqpt_bin --critical-times`). The atlas-side verifier
closes this as the **Stage 2 libm closed form**: in the analytic
limit it computes `k* = π/2` (from `cos k* = 0`),
`ε_{g₁=0}(k*) = 2`, `t* = π/2`, `t*₀ = π/4` via libm `π`, and
asserts `|t*₀ − π/4| < 1e-12`; it also checks the **control case**
`g₀=0.4→g₁=0.8` (both `< 1`): `cos k* = (1+0.32)/1.2 = 1.1 > 1`
⇒ NO real `k*` ⇒ no DQPT cusp (smooth `λ_∞`).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-FORMAL** (Stage 2 — `t*₀ = π/4` is a
  transcendental closed form computed via libm `π`,
  `|err| < 1e-12`; the underlying `cos k* = 0 ⇒ k* = π/2`,
  `ε_{g₁=0} = 2`, `t* = π/2` chain is exact at the analytic
  limit).
- **Axis:** §3 PHYS (dynamical quantum phase transition / TFIM
  free-fermion quench) · cross-link §6 COSMO (Loschmidt-echo /
  boundary partition function) · §2 MATH (`π/4` transcendental).
- **Real-limit anchor (`g3`):**
  - **Heyl, Polkovnikov, Kehrein**, *Phys. Rev. Lett.* **110**,
    135704 (2013), DOI `10.1103/PhysRevLett.110.135704` /
    arXiv:1206.2505 — the founding DQPT paper; Eq. 4–5 closed
    form, the Fisher-zero critical times `t*_n = t*(n+½)`.
  - **Pfeuty**, *Ann. Phys.* **57**, 79 (1970) — the exact
    free-fermion (Jordan-Wigner + Bogoliubov) solution of the
    TFIM giving `ε_g(k) = 2√(1+g²−2g cos k)`.
  - **Heyl**, *Rep. Prog. Phys.* **81**, 054001 (2018) — DQPT
    review (the `t*_n` non-analyticity structure).
  - [compiler invariant — `π/4` is computed via the deterministic
    libm `π`; `cos(π/2)=0` and `ε_{g=0}(k)=2` are exact at the
    analytic limit; `|err| < 1e-12`].
- **Provenance:** sim-universe `dqpt-loschmidt/` (Tier-A2) ·
  `dqpt-loschmidt/module/dqpt.hexa` (Route B closed form,
  `_critical_times`) · AGENTS.tape `@D g19` · `@X x_heyl_dqpt`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_value`** — the fundamental cusp is at
   `t*₀ = π/4 ≈ 0.785398`, NOT `π/2` (that is `t*`, the full
   period) nor `π` nor `π/8`. If the verifier reports a value
   ≠ `π/4` for the `g₀→∞,g₁→0` analytic limit, the `(n+½)`
   factor is wrong — FIRES. Verifier asserts `t*₀ = t*·½ = π/4`.
2. **`F2_no_crossing_no_cusp`** — a DQPT exists **iff** the
   quench crosses `g_c = 1` (a real `k* ∈ (0,π)` exists). For
   the control `g₀=0.4→g₁=0.8` (both `< 1`),
   `cos k* = (1+0.32)/1.2 ≈ 1.1 > 1` ⇒ NO real `k*` ⇒ NO cusp.
   If the verifier reports a cusp for the control case, the
   crossing criterion is wrong — FIRES. Verifier asserts
   `|cos k*| > 1 ⇒ no DQPT` for the control.
3. **`F3_wrong_dispersion`** — `ε_g(k) = 2√(1+g²−2g cos k)`; at
   `g₁ = 0` this is `ε = 2` (k-independent). If the verifier uses
   `ε = 1` (dropping the factor 2) → `t* = π` → `t*₀ = π/2`
   (wrong), FIRES. Verifier asserts `ε_{g=0}(k) = 2` exactly and
   `t* = π/2`.
4. **`F4_wrong_kstar`** — `cos k* = (1+g₀g₁)/(g₀+g₁)`; at the
   analytic limit `g₀→∞, g₁→0` this → `0` ⇒ `k* = π/2`. If the
   verifier uses `k* = 0` or `k* = π` (band edges, where
   `sin²(2Δ_k) ≠ 1`, so no Fisher zero), FIRES. Verifier asserts
   `cos k* = 0 ⇒ k* = π/2` and `sin²(2Δ_{k*}) = 1` there.
5. **`F5_finite_N_sharp`** — the cusp is **sharp ONLY in the
   N→∞ closed form**; the finite-N Route-A `λ_N(t)` has a
   *rounded* near-kink (the genuine finite-size rounding of the
   non-analyticity, `@D g19`, stated not faked). If the verifier
   claims a literally divergent `d²λ/dt²` at finite N, the
   over-claim FIRES. Verifier closes the `N→∞` closed-form
   `t*₀ = π/4` ONLY and states finite-N is rounded.
6. **`F6_integrable_only`** — the closed form exists **only for
   the integrable TFIM** (free-fermion mappable). A
   non-integrable model has NO Route-B closed form. If the
   verifier claims `t*₀ = π/4` for a generic non-integrable
   quench, the integrability restriction is violated — FIRES.
   Verifier closes the TFIM free-fermion case ONLY.

## Honest C3

This atom is the **closed-form fundamental DQPT critical time
`t*₀ = π/4`** for the **integrable TFIM** quench in the analytic
limit `g₀→∞, g₁→0` (the module's unambiguous selftest quench). The
non-analyticity is **sharp ONLY in the N→∞ closed form** (Route B);
the finite-N exact-2ᴺ Route-A `λ_N(t)` has rounded near-kinks (the
expected finite-size rounding, `@D g19`, stated not faked — the
2ᴺ memory wall caps Route A at `N ≲ 24`). It is NOT a claim about
a non-integrable model's thermodynamic limit (no Route B exists
there), NOT decoherent. The atom absorbs the exact TFIM
critical-time closed form only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `dqpt-loschmidt/` (Tier-A2).
Paper: Heyl, Polkovnikov, Kehrein, *Phys. Rev. Lett.* **110**,
135704 (2013) / arXiv:1206.2505. AGENTS.tape `@D g19` /
`@X x_heyl_dqpt`.
