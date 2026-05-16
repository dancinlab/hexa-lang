# wdw-minisuperspace-canonical-algebra-A2c2-omega-ratio

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Wheeler–DeWitt minisuperspace model of Basilakos,
Kouniatalis, Saridakis, Tzerefos (2025), *Phys. Lett. B* (2026),
arXiv:2512.18818, the non-trivial canonical transformation
(Eq. `xydef`)

    x = A a^{3/2} sinh(cφ) ,   y = A a^{3/2} cosh(cφ)
    ⇒ y² − x² = A² a³ ,   tanh(cφ) = x/y

maps the constrained Hamiltonian onto a **2D hyperbolic
oscillator** *only* for the special parameter values (Eq.
`Ac_values`)

    A² = 8/3 ,   c² = 3/8

with oscillator frequencies (Eq. `omegas`)

    ω₁² = Λ / A² ,   ω₂² = 2Λ / A²  .

This pins **three exact rational / surd identities**:

    (1)  A² · c² = (8/3)·(3/8) = **1**        (the closure
         condition that makes the Lagrangian a clean difference
         of two oscillators)
    (2)  ω₂² / ω₁² = (2Λ/A²)/(Λ/A²) = **2**
         ⇒  ω₂ = **√2 · ω₁**                  (FIXED frequency
         ratio, Eq. `omega_relation`)
    (3)  late-time de-Sitter Hubble rate (Eq. `HBohm_xy`, §IV.D):
         α ∝ ((y²)/A²)^{1/3} ∝ e^{(2/3)ω₂ τ}
         ⇒  **H_late = (2/3) ω₂**             (the DE-dominated
         attractor exponent)

Identities (1)–(2) are **exact ℚ/surd** (`A²c²=1` is integer-
rational; `ω₂²=2ω₁²` is rational-exact, `ω₂=√2 ω₁` a surd);
(3) is the exact closed-form structural relation `H_late=(2/3)ω₂`.

## Hexa-native verification

The sim-universe `wdw-minisuperspace/module/wdw.hexa` selftest
emits the constants and the late-time limit directly:

    consts: A²=2.666667  c²=0.375  ω₁=0.612372
            ω₂=0.866025 (=√2·ω₁)  E*=1.000000
    (b) Bohmian trajectory → late-time ΛCDM/de-Sitter :
        H_late = 0.579172  H_deSitter=(2/3)ω₂ = 0.577350
        dev=0.003156 (OK — de-Sitter expansion)

with sentinel `__SIM_UNIVERSE_WDW__ PASS` and disclosure
`entropy_source=deterministic-exact` + the interpretational-status
flag (the de Broglie–Bohm reading is ONE interpretation — flagged,
`@D g20`). Build + run:

    bash state/ubu-build.sh \
        wdw-minisuperspace/module/wdw.hexa wdw_bin --selftest

(or `./state/wdw_bin --classical-limit`). The atlas-side verifier
closes (1)–(3): it asserts the **exact rational** `A²·c² = 1`
(numerator product `8·3 == 3·8`), `ω₂² = 2·ω₁²` (so
`ω₂²/ω₁² == 2` exactly via `ω_i² = Λ/A²` cancelling Λ and A²),
the **surd** `ω₂ = √2·ω₁` via libm `sqrt` (`|ω₂/ω₁ − √2| <
1e-12`), and the **closed-form** late-time exponent
`H_late = (2/3)·ω₂` (from `α ∝ e^{(2/3)ω₂τ}`).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — `A²·c²=1` and
  `ω₂²/ω₁²=2` and `H_late=(2/3)ω₂` are exact rational/closed-form
  identities; the surd `ω₂=√2 ω₁` is the libm-precision Stage 2
  corollary `|err|<1e-12`).
- **Axis:** §3 PHYS (canonical quantum cosmology / Wheeler–DeWitt
  minisuperspace) · cross-link §6 COSMO (late-time ΛCDM/de-Sitter
  attractor) · §2 MATH (exact rational closure `A²c²=1`, surd
  `√2`).
- **Real-limit anchor (`g3`):**
  - **Basilakos, Kouniatalis, Saridakis, Tzerefos**,
    *Phys. Lett. B* (2026) / arXiv:2512.18818 — Eqs. `Ac_values`
    (`A²=8/3, c²=3/8`), `omegas`/`omega_relation`
    (`ω₂=√2 ω₁`), `HBohm_xy` / §IV.D (`H_late=(2/3)ω₂`).
  - **DeWitt 1967**, *Phys. Rev.* **160**, 1113 — the
    Wheeler–DeWitt equation (the constrained Hamiltonian
    quantized here).
  - **Paliathanasis et al. 2014/2015** — minisuperspace
    canonical transformations rendering the WDW equation
    exactly solvable.
  - [compiler invariant — `A²c²=1` and `ω₂²/ω₁²=2` are exact ℚ
    quantities (the Λ and A² factors cancel identically); `√2`
    via deterministic libm `sqrt`, `|err|<1e-12`].
- **Provenance:** sim-universe `wdw-minisuperspace/` (Tier-A2) ·
  `wdw-minisuperspace/module/wdw.hexa` (constants block,
  `_scale_factor`, `H_Bohm`) · AGENTS.tape `@D g20` ·
  `@X x_basilakos_wdw`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_closure_broken`** — the closure condition is
   `A²·c² = 1` *exactly* (`(8/3)·(3/8)`). If the verifier finds
   `A²c² ≠ 1` (e.g. uses `A²=8/3, c²=1/2` ⇒ `4/3 ≠ 1`), the
   Lagrangian is NOT a clean oscillator difference — FIRES.
   Verifier asserts the integer-cross identity `8·3 == 3·8`
   (`A²c²=1`).
2. **`F2_wrong_freq_ratio`** — `ω₂² = 2 ω₁²` ⇒ `ω₂ = √2 ω₁`,
   NOT `ω₂ = 2 ω₁` nor `ω₂ = ω₁`. If the verifier reports
   `ω₂/ω₁ = 2` (squaring confusion) or `1` (degenerate), the
   FIXED ratio is wrong — FIRES. Verifier asserts
   `ω₂²/ω₁² == 2` (ℚ-exact) and `|ω₂/ω₁ − √2| < 1e-12`.
3. **`F3_lambda_A_not_cancel`** — `ω_i² = (·)Λ/A²`, so the
   ratio `ω₂²/ω₁²` is **independent of Λ and A²** (they cancel
   identically). If the verifier finds the ratio depending on Λ
   or A² (a non-cancelling error), FIRES. Verifier sweeps
   several `(Λ, A²)` and asserts `ω₂²/ω₁² ≡ 2` at every one.
4. **`F4_wrong_desitter_exponent`** — the late-time Hubble rate
   is `H_late = (2/3)ω₂` (from `α ∝ (y²/A²)^{1/3}` and
   `y² ∝ e^{2ω₂τ}` ⇒ `α ∝ e^{(2/3)ω₂τ}`). If the verifier
   reports `H_late = ω₂` (dropping the `2/3` from the `a³`
   power) or `(1/3)ω₂`, the de-Sitter attractor is wrong —
   FIRES. Verifier asserts `H_late = (2/3)·ω₂` exactly.
5. **`F5_generic_potential`** — exact solvability is a property
   of the **special** Basilakos potential
   `U(φ)=(Λ/2)(cosh²cφ+1)` with `A²=8/3, c²=3/8` — it is **NOT**
   generic. If the verifier claims the `√2` ratio for an
   arbitrary potential / arbitrary `(A,c)`, the specialness is
   violated — FIRES. Verifier closes the `A²=8/3, c²=3/8` map
   ONLY.
6. **`F6_bohm_not_privileged`** — the `H_late=(2/3)ω₂` de-Sitter
   reading uses the de Broglie–Bohm trajectory, which is **ONE
   interpretation among several** (Copenhagen, many-worlds,
   consistent-histories) of the *same* timeless WDW wave
   function — NOT privileged or established (`@D g20`, mirrors
   ca-qm `@D g9`). If the verifier asserts the Bohmian reading
   is THE established quantum cosmology, the metaphysical
   over-claim FIRES. Verifier closes the *algebraic* identities
   (1)–(3) and flags the interpretational status of (3).

## Honest C3

This atom is the **exact canonical-transformation algebra** of
the Basilakos minisuperspace model: the rational closure
`A²·c²=1`, the fixed frequency ratio `ω₂²=2ω₁² ⇒ ω₂=√2 ω₁`, and
the closed-form late-time de-Sitter exponent `H_late=(2/3)ω₂`. It
is an EXACT closed-form solver for the minisuperspace
**TRUNCATION** ONLY — minisuperspace freezes ALL
inhomogeneous/perturbative modes BY HAND (no graviton, no
perturbation spectrum), so it is **NOT** canonical quantum
gravity. The exact solvability is a property of the **special**
Basilakos potential, **not** generic. The de Broglie–Bohm
(pilot-wave) reading used for the trajectory / reconstructed
scale-factor history (identity (3)) is **ONE** interpretation
among several of the *same* WDW wave function — flagged, NOT
privileged (`@D g20`, mirrors ca-qm `@D g9`); operator-ordering
ambiguity is unresolved. The late-time ΛCDM/de-Sitter agreement
is a property of this *toy* truncated homogeneous sector, **NOT**
a data fit and **NOT** empirical evidence about the real universe
(pairs with `@F f1`: the cosmological framing is the project's
THEME, never a derivation rule). There is **NO** computational
memory wall (closed-form special-function + `O(steps)` RK4); the
only ceiling is the *physical* minisuperspace truncation itself.
The atom absorbs the exact algebraic identities only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `wdw-minisuperspace/` (Tier-A2).
Paper: Basilakos, Kouniatalis, Saridakis, Tzerefos, *Phys. Lett.
B* (2026) / arXiv:2512.18818; DeWitt, *Phys. Rev.* **160**, 1113
(1967). AGENTS.tape `@D g20` / `@X x_basilakos_wdw`.
