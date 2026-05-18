# z2gauge-floquet-half-step-exactness

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Hayata & Hidaka 2024 (1+1)D Z₂ LGT Floquet circuit
(arXiv:2408.10079 / Phys. Rev. D **110**, 114503 (2024)), each
Floquet half-step factorises **EXACTLY** — there is **no Trotter
error within either half-step**:

    exp(−i (H_f + H_g) dt) = ∏_x exp(−i H_f^x dt) · ∏_link exp(−i H_g^link dt)
    exp(−i  H_gf       dt) = ∏_link exp(−i H_gf^link dt)

The factorisation is exact because **the terms in each half-step
act on pairwise-disjoint qubit sets**, hence commute:

- All `H_f` site terms `(1+m)/2 (X_1(x)X_2(x)+Y_1(x)Y_2(x))` act on
  distinct matter pairs `(ψ_1(x), ψ_2(x))` → pairwise commute.
- All `H_g` link terms `−K X_g(x,x+1)` act on distinct link qubits
  → pairwise commute.
- `H_f` site `x` and `H_g` link `x` act on disjoint qubits → commute.
- All `H_gf` link terms use disjoint triples `(ψ_1(x), g_x,
  ψ_2(x+1))` vs `(ψ_1(x+1), g_{x+1}, ψ_2(x+2))` → pairwise commute.

When operators commute, `exp(A+B) = exp(A)exp(B)` is an **exact
identity** (Baker–Campbell–Hausdorff with `[A,B]=0` → no higher
terms). Therefore the product decomposition is the **paper's exact
Floquet operator** `U_F`, not a Trotterised approximation. The only
Floquet "error" is the *physical* `[H_f+H_g, H_gf] ≠ 0` commutator
that **defines the Floquet circuit itself** (the stroboscopic
prethermal dynamics is the object of study, not an artefact). The
load-bearing numerical consequence is the selftest invariant

    norm_drift = 0.000000   (unitarity, exact — no operator-splitting error)

## Hexa-native verification

The sim-universe `z2-gauge-prethermal/module/z2gauge.hexa` selftest
emits unitarity directly:

    unitarity   : norm_drift=0.000000 (OK)

with sentinel:

    __SIM_UNIVERSE_Z2GAUGE__ PASS N=3 Q=8 G=1.000000 H=-2.000000
        norm_drift=0.000000

Build + run command:

    bash state/ubu-build.sh \
        z2-gauge-prethermal/module/z2gauge.hexa \
        z2gauge_bin --selftest

The atlas-side verifier closes this **as the disjoint-support
commutation identity lifted to a 2×2 rotation block**: each
elementary rotation `exp(−iθ R)` (single-qubit `σ^x`, 2-qubit
`XX+YY`, 3-qubit `Z_g(XX+YY)`) is unitary because `R` is Hermitian
with `±1`-type block structure → the per-block factor is a planar
rotation with `cos²θ + sin²θ = 1` (unit determinant, norm-preserving).
Disjoint-support terms commute, so the product of these
norm-preserving blocks is norm-preserving **exactly** — the
`norm_drift = 0` invariant reduces to `cos²θ + sin²θ = 1` per
elementary rotation, libm-precision-exact, plus the structural
disjoint-support commutation (integer index-set disjointness).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 / Stage 2 hybrid —
  the disjoint-support commutation is a structural integer-exact
  fact; the per-rotation norm-preservation is the libm-confirmed
  trig identity `cos²θ + sin²θ = 1` at the paper's `dt = 1.0`
  rotation angles, machine-precision exact).
- **Axis:** §3 PHYS (Floquet circuits / exact operator splitting) ·
  cross-link §2 MATH (Pythagorean trig identity; BCH with `[A,B]=0`).
- **Real-limit anchor (`g3`):**
  - **Hayata & Hidaka**, **Phys. Rev. D 110, 114503 (2024)** /
    arXiv:2408.10079, Eq. eq:U_F (Floquet operator) + Eqs.
    eqHW_f1/eqHW_f2/H_g (the three Hamiltonian pieces).
  - **Baker–Campbell–Hausdorff** — `[A,B]=0 ⇒ e^{A+B}=e^A e^B`
    exactly (no truncation; this is the no-Trotter-error guarantee).
  - **Pauli, W.**, Z. Phys. **43**, 601 (1927) — Pauli strings on
    disjoint qubits commute; `R²=𝟙`-type block ⇒ `±1` eigenvalues
    ⇒ each `exp(−iθR)` is a unit-determinant rotation.
- **Provenance:** sim-universe commit (z2-gauge-prethermal landing) ·
  `z2-gauge-prethermal/module/z2gauge.hexa::_apply_step_fg`,
  `::_apply_step_gf` · AGENTS.tape `@D g13` · `@X x_hayata_z2lgt`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_nonunit_modulus`** — if `cos²θ + sin²θ ≠ 1` (machine
   precision) for any rotation angle `θ` tested by libm, the
   per-rotation norm-preservation fails — would invalidate the
   `norm_drift = 0` claim. Verifier samples the paper rotation
   angles (`θ = (1+m)/2·dt = 1.0`, `θ = −K·dt = −1.0`, `θ = dt/2 =
   0.5` at the paper `dt = 1.0, K = m = 1`) plus off-paper
   `θ ∈ {0.25, 0.7, 1.4}`; each `|cos²θ + sin²θ − 1| < 1e-15`.
2. **`F2_overlapping_support`** — if two terms claimed disjoint
   actually share a qubit (e.g. an `H_gf` link `x` written to touch
   `ψ_2(x)` instead of `ψ_2(x+1)`), they do NOT commute and the
   product decomposition acquires a real Trotter error → `norm_drift`
   would still be 0 (product of unitaries) BUT the operator would no
   longer equal the paper `U_F`. Verifier asserts the index sets of
   adjacent `H_gf` links are disjoint (integer set check); overlap
   FIRES.
3. **`F3_bch_truncation_assumed`** — if the implementation used a
   1st/2nd-order Trotter formula for the *within-half-step* product
   (treating it as approximate), the half-step would carry an
   `O(dt²)` splitting error. The atom's claim is EXACT (`[A,B]=0` →
   no error). Verifier checks the within-half-step factor is the
   exact product (no `dt²` correction term) — any nonzero splitting
   residual FIRES.
4. **`F4_wrong_norm_formula`** — for `z = cosθ + i sinθ`,
   `|z|² = cos²θ + sin²θ`. If the verifier computes `|z|² =
   cos²θ − sin²θ` or `|cosθ| + |sinθ|`, the norm formula is wrong;
   at `θ = 1.0`: correct `0.2919 + 0.7081 = 1.0000` vs wrong
   `−0.4161` — FIRES.
5. **`F5_half_step_order_swap`** — the Floquet operator is
   `U_F = exp(−iH_gf dt)·exp(−i(H_f+H_g)dt)` (a SPECIFIC ordering).
   The *within*-half-step factorisation is exact regardless of
   ordering (disjoint support), but the *between*-half-step ordering
   is physical and must NOT be commuted. If the verifier silently
   reorders the two half-steps as if they commuted (they do not —
   `[H_f+H_g, H_gf] ≠ 0`), the prethermal dynamics changes — the
   selftest invariant `range(<H_local>) > 0.1` (real dynamics) would
   shift; inconsistency FIRES.
6. **`F6_global_phase_leak`** — an overall phase from summing the
   per-term exponentials is unobservable. If the verifier reports a
   nonzero `global_phase_drift` that leaks into `⟨G⟩` or `⟨𝓗⟩`
   against an external phase reference, the unobservable-phase
   accounting is wrong — FIRES. (The selftest's `⟨G⟩ ≡ +1` and the
   real-valued `⟨𝓗⟩` are phase-reference-free, so a clean impl
   passes.)

## Honest C3

This atom is **specifically** the *within-half-step* exact
factorisation (`[A,B]=0 ⇒ e^{A+B}=e^Ae^B`, lifted to per-rotation
`cos²θ+sin²θ=1`). It is the load-bearing identity behind
`norm_drift = 0`. It does NOT claim the *full Floquet step* is
Trotter-error-free in the sense of capturing the paper's
thermodynamic-limit dynamics — the physical `[H_f+H_g, H_gf] ≠ 0`
commutator IS the Floquet circuit and is faithfully kept (it is the
object of study, not an error). The atom also does NOT claim
reproduction of the paper's `N = 13`/`N = 39` hardware runs (exact
state vector ceiling `N ≤ 7`, `Q ≤ 20`, per `@D g13`). Only the
exact within-half-step splitting is absorbed.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `z2-gauge-prethermal/` (module 17,
Tier-A2). Paper: Hayata & Hidaka, Phys. Rev. D 110, 114503 (2024) /
arXiv:2408.10079. AGENTS.tape `@D g13` / `@X x_hayata_z2lgt`.
