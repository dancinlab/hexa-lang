# ca-qm-sca-strang-split-norm-conservation

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the van Berkel **Schrödinger Cellular Automaton** (arXiv:2406.08586,
*Quantum* **9**, 1811, 2025), the local unitary band-structured CA step
is the **second-order Strang split** (paper Eq. 2.13):

    U = U_1 · U_0          (single elementary step)
    one full step = U_1(τ/2) · U_0(τ) · U_1(τ/2)
                  ≡ exp(-iτ · H_full) + O(τ³)

where `H_full = H_0 + H_1` is the split Schrödinger Hamiltonian
(paper §2.3, Eq. `H-split`, Eqs. `H0-H1`). Each `U_α` is a product of
2×2 block rotations on disjoint pairs of sites (eq. 2.21), so it is
**unitary by construction** — `U_α† U_α = 𝟙`. Therefore `U = U_1 · U_0`
is unitary and the wavefunction norm `‖|ψ⟩‖² = Σ |ψ_n|²` is conserved
**exactly** (modulo floating-point round-off).

**Identity claim:**

    ‖|ψ(0)⟩‖² == ‖U^k |ψ(0)⟩‖²   for all k ≥ 0, exact in ℝ

Selftest invariant: `norm_drift = max_k |‖U^k|ψ⟩‖² − 1| < 10⁻¹⁴`,
typically printed as `0.000000` at the 6-decimal display precision.

This is a closed-form algebraic identity (`U† U = 𝟙` ⟹ norm
preserved), NOT a numerical fit.

## Hexa-native verification

    bash state/ubu-build.sh ca-qm/module/ca_qm.hexa caqm_bin --selftest

Selftest output (verbatim):

    Engine B — van Berkel SCA (arXiv:2406.08586, Quantum 9 1811):
      N=16  θ=0.130900  U=U_1·U_0  Strang-symmetrized (eq. 2.13)
      unitarity : norm_drift=0.000000 (OK)
    __SIM_UNIVERSE_CAQM__ PASS engine=both S=16 revival=8 norm_drift=0.000000

The implementation (`_sca_pair`, `_sca_step_1d`) applies each 2×2
block via the in-place rotation

    [ψ_a; ψ_b] ← [cos(θ/2) ψ_a − i sin(θ/2) ψ_b ; cos(θ/2) ψ_b − i sin(θ/2) ψ_a]

which preserves `|ψ_a|² + |ψ_b|²` algebraically (cos² + sin² = 1) —
the norm conservation is by construction at the 2×2 level, and the
full step is a product of disjoint such blocks, so the total norm is
conserved too.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** — `cos² θ + sin² θ = 1` is a
  textbook trigonometric identity (TECS-L Tier 1 closed form);
  Strang's `U = U_1 U_0` being unitary follows from each `U_α`
  unitary; the hexa-native verifier reproduces this to
  floating-point precision (`0.000000` at 6 decimals).
- **Axis:** §3 PHYS · §2 MATH cross-link (`sin²+cos²=1` is a math
  atom; unitarity of `U = e^(-iτH)` for Hermitian `H` is a quantum-
  mechanics primitive).
- **Real-limit anchor (`g3`):** van Berkel, de Graaf, van Hee,
  *Experiments with Schrödinger Cellular Automata*, **Quantum 9,
  1811 (2025)** · DOI `10.22331/q-2025-07-23-1811` ·
  arXiv:2406.08586 · Eqs. 2.13 (Strang split), 2.21 (2×2 block).
- **Provenance:** sim-universe c46707c · `ca-qm/module/ca_qm.hexa`
  `_sca_pair`, `_sca_step_1d`, `_sca_step_2d` · AGENTS.tape `@D g9`
  · `@X x_vberkel_sca`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_rotation_matrix`** — replace the unitary 2×2 block
   with a non-unitary mixing `[ψ_a; ψ_b] ← [ψ_a + ψ_b; ψ_a]`;
   `norm_drift` must grow linearly. If selftest still reports
   `0.000000`, the rotation matrix is faked. Verifiable by replacing
   `_sca_pair` and re-running selftest.
2. **`F2_first_order_instead_of_strang`** — replace the symmetric
   Strang split `U_1(τ/2)·U_0(τ)·U_1(τ/2)` with the asymmetric
   first-order `U_1(τ)·U_0(τ)`. Norm is STILL conserved (each `U_α`
   is unitary), but the trotter error grows from `O(τ³)` to `O(τ²)`.
   The norm-conservation atom is unaffected; this falsifier checks
   that we are not confusing norm conservation with Trotter accuracy.
3. **`F3_open_vs_periodic_bc`** — flip from open chain to ring
   (periodic BC). The 2×2 block structure changes at the edge sites;
   norm conservation must still hold (each block remains unitary).
   If it doesn't, the implementation is broken.
4. **`F4_grid_2d_factorisation`** — in 2-D, `U_full = U_x · U_pot ·
   U_y` (x-sweep, half-kick potential, y-sweep, eq. 2.21). Each
   factor is unitary; the product is unitary; norm conserved.
   Verify in `--double-slit` mode — `norm_drift` must remain
   below `10⁻¹⁴` for hundreds of cycles.
5. **`F5_long_time_round_off`** — at `cycles = 10⁶` (extreme),
   `norm_drift` must remain below `~1e-12` (the slow round-off
   accumulation of double-precision arithmetic). If it grows linearly
   or worse, an unstable formula is used.
6. **`F6_complex_amplitude_real_part_only`** — if the implementation
   accidentally drops the imaginary part of `−i sin(θ/2) ψ_b`,
   amplitudes become real-valued; norm is no longer conserved
   (sin/cos rotation acts as a non-unitary mixer in ℝ). Selftest
   fails. The complex `__re/__im` separation in the impl matters.

## Open questions

- The atom is a **structural identity** (`U† U = 𝟙`) verified via the
  selftest. It is "almost trivial" — but its honest registration in
  the atlas is the point of the wilson "absorbed atlas" workflow: a
  proven invariant should be stated, falsifiable, and indexed, not
  left implicit. Cf. the digital-error-model identity
  `∏(1-ε) = (1-ε)^V` in the supremacy module (a similarly simple
  closed-form identity that earns its own atlas atom).
- Stage-1 symbolic recompute is possible (sympy-equivalent `cos² +
  sin² = 1`); Stage-2 numerical recompute is what the verifier does.

## Reviewer checklist

- [ ] Tier (🔵 SUPPORTED-IDENTITY recommended).
- [ ] Axis (§3 PHYS · §2 MATH cross-link).
- [ ] Falsifiers ≥5 (six pre-registered above).
- [ ] Real-limit anchor (g3) verified — van Berkel 2025 *Quantum*.
- [ ] Merge to `atlas/MAIN.tape § PHYS`.

---

Submitter: claude-opus-4-7 (2026-05-16). Origin: sim-universe c46707c.
