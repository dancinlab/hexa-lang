# dtc-bond-ising-diag-phase-unitarity

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

In the Bao et al. 2025 kicked-Ising Floquet unitary (arXiv:2510.24059
main.tex L189), the **bond term**

    exp(−i J σ̂ᶻ_i σ̂ᶻ_{i+1})

is **diagonal** in the computational basis with eigenvalues
`exp(±i J)` (sign depends on whether neighbouring spins are
parallel or anti-parallel). Per-bond unitarity is the closed-form
trig identity:

    |exp(i J)|² = cos²(J) + sin²(J) = 1

i.e., each per-bond factor has unit modulus, so the diagonal Ising
bond application is exactly unitary by construction — **no
operator-splitting error, no Trotter error**. This is the
**load-bearing identity** behind the `dtc` module's Trotter-free
claim: the full Floquet unitary `U_F` is a product of single-qubit
rotations + diagonal Ising bonds + a global `R^y` sandwich for the
tilted-z perturbation, every piece exactly unitary. The `dtc.hexa`
`norm_drift = 0.000000` selftest invariant **reduces to this
identity** at every bond.

## Hexa-native verification

The sim-universe `fock-prethermal-dtc/module/dtc.hexa` selftest emits
unitarity directly:

    unitarity   : norm_drift=0.000000 (OK)

Sentinel:

    __SIM_UNIVERSE_DTC__ PASS N=8 state=1FM sub_peak=5.026529
        dw_drift=0.306747 norm_drift=0.000000

The `_apply_ising_diag(J)` helper scans every basis state `b`, reads
each bond sign `s_k · s_{k+1} ∈ {+1, −1}` (where `s_k = ±1` is the
σ^z eigenvalue at site `k`), and multiplies the amplitude by
`exp(i J · s_k · s_{k+1})`. Each multiplication is a phase rotation
in `ℂ` — preserves `|amp_b|²` exactly. After all `L − 1` bonds (or
`L` bonds with PBC), the total state norm is unchanged. The atlas
verifier closes this **as the trig identity** `cos²(J) + sin²(J) = 1`
at a specific `J`, which is libm-precision-exact.

Build + run command:

    bash state/ubu-build.sh \
        fock-prethermal-dtc/module/dtc.hexa \
        dtc_bin --selftest

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 / Stage 2 hybrid —
  the bond *eigenvalues* `exp(±i J)` are unit-modulus by the
  textbook identity `|e^{iφ}| = 1`; the libm-cross-check
  `cos²(J) + sin²(J) = 1` to machine precision (≤ `1e-15`) at the
  paper's `J = 1` value confirms hexa-native libm reproduces the
  identity).
- **Axis:** §3 PHYS (Floquet unitaries / time-crystal lattice
  models) · cross-link §2 MATH (Pythagorean trig identity).
- **Real-limit anchor (`g3`):**
  - **Bao et al.**, arXiv:2510.24059 (2025), main.tex L189 (the
    full `U_F` formula in which the bond appears).
  - **Pauli, W.**, *Zur Quantenmechanik des magnetischen Elektrons*,
    Z. Phys. **43**, 601–623 (1927) — Pauli matrices `σ̂ᶻ` are
    Hermitian with eigenvalues `±1`, so `σ̂ᶻ_i σ̂ᶻ_{i+1}` is
    Hermitian with eigenvalues `±1`, so `exp(−i J σ̂ᶻ σ̂ᶻ)` is unitary
    with eigenvalues `exp(∓i J)`.
- **Provenance:** sim-universe commit (fock-prethermal-dtc landing) ·
  `fock-prethermal-dtc/module/dtc.hexa::_apply_ising_diag` ·
  AGENTS.tape `@D g12` · `@X x_bao_dtc`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_non_unit_modulus`** — if `cos²(J) + sin²(J) ≠ 1` (to
   machine precision) for any specific `J` value tested by libm,
   the trig identity itself fails — would invalidate the entire
   numerics, not just this atom. Verifier samples `J = 1.0` (paper
   value) AND `J = 0.5, 0.7, 1.5, 2.0` (off-paper) and checks
   `|cos²+sin²−1| < 1e-15` at each.
2. **`F2_wrong_sign_convention`** — eigenvalues are `exp(±i J)`,
   NOT `exp(i J)` always. Specifically, on a basis state with
   `σ̂ᶻ_i σ̂ᶻ_{i+1} = +1` (parallel neighbours), the factor is
   `exp(−i J)`; on a state with `σ̂ᶻ_i σ̂ᶻ_{i+1} = −1` (anti-parallel),
   it's `exp(+i J)`. Both have unit modulus, but if the
   implementation sums them coherently as `(exp(iJ) + exp(−iJ))/2 =
   cos(J)` and treats THAT as a unitary factor, that's a real
   number (not on the unit circle for general J) — falsified.
3. **`F3_complex_norm_check`** — for a complex number `z = a + i b`,
   `|z|² = a² + b²`. For `z = exp(i J) = cos J + i sin J`,
   `|z|² = cos²(J) + sin²(J)`. If the implementation computes
   `|z|² = a² − b²` or `|z|² = |a| + |b|` (taxicab metric), the
   norm formula is wrong — falsified by direct numerical check at
   `J = 1.0`: `(0.5403)² + (0.8415)² = 0.2919 + 0.7081 = 1.0000`
   (correct) vs `0.5403² − 0.8415² = −0.4161` (wrong).
4. **`F4_diagonal_basis_violation`** — if `exp(−i J σ̂ᶻ σ̂ᶻ)` is
   implemented as a non-diagonal matrix (e.g., the implementer
   confuses `σ̂ᶻ` with `σ̂ˣ`), it would mix computational basis
   states and unitarity in the *full* state-vector evolution would
   require Trotter / matrix exponentiation. The norm-conservation
   would still hold (matrix exp of an antihermitian is unitary),
   but the atom is *specifically* about the per-bond per-amplitude
   phase action — the diagonal claim. If the verifier reports
   `|<b|U|b'>| ≠ δ_{b,b'}` for any `b ≠ b'` after the bond
   application alone, falsified.
5. **`F5_eigenvalue_specificity`** — the eigenvalues are
   `exp(±i J)`, NOT `exp(±i 2J)` (a common error from forgetting
   the `J σ̂ᶻ σ̂ᶻ` doesn't carry a `/2` like the single-qubit
   rotations `R^z(θ) = exp(−i θ/2 σ̂ᶻ)`). Specifically: at `J = π`,
   the eigenvalues should be `exp(±i π) = −1`, NOT `+1` (which
   would be `exp(±i 2π) = 1`). The selftest at `J = 1, λ₁ = 1.2`
   (thermal) shows the subharmonic peak collapses to `≈ 1.45`,
   consistent with `J = 1` not `J = 2` (with `J = 2`, FSP would
   shift to a different λ₁ regime). If the verifier silently
   doubles `J`, the regime ordering shifts and `F4 + F1` falsify.
6. **`F6_global_phase_drift`** — a global phase `exp(−i J · N)`
   from summing N bonds is *unobservable* (overall phase, not
   physical). If the verifier hard-codes the global phase to zero
   and reports `norm_drift = 0` correctly, the atom passes. If the
   verifier reports a nonzero `global_phase_drift` accumulating
   over cycles, that's also unobservable — atom still passes — but
   if it leaks into observables (e.g., `<σ̂ᶻ_j>` measured against
   an external phase reference), falsified.

## Open questions / risks

- The atom is *specifically* the per-bond unit-modulus identity,
  NOT the full Floquet unitary. The full `U_F` unitarity is the
  *combined* claim of (a) single-qubit rotations are unitary, (b)
  diagonal Ising bonds are unitary (this atom), (c) tilted-z bond
  via `R^y` sandwich is unitary (composition of unitaries). Each is
  a separate atom; the atlas should register them piecewise.
- The verifier samples `J = 1.0` (paper-fixed) plus 4 off-paper
  values. A reviewer may prefer a *symbolic* Stage 1 atom for the
  identity itself ("any phase has unit modulus") and a separate
  Stage 2 atom for the libm reproduction at specific J. Recommend
  the libm Stage 2 here (matches the existing `caqm_sca_strang_
  trig_identity` pattern at θ = 0.130900).

## Reviewer checklist

- [ ] Tier (🔵 SUPPORTED-IDENTITY recommended).
- [ ] Axis (§3 PHYS · §2 MATH cross-link).
- [ ] Falsifiers ≥5 (six pre-registered above).
- [ ] Real-limit anchor (g3) verified — Bao 2025 + Pauli 1927.
- [ ] Merge to `atlas/MAIN.tape § PHYS`.

---

Submitter: claude-opus-4-7 (sim-universe absorption cycle, 2026-05-16).
Origin: sim-universe `fock-prethermal-dtc/`.
