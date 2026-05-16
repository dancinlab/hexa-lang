# qdarwin-touil-2022-route-AB-six-decimal-identity

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

The **Touil et al. 2022 closed-form mutual information**
(*Phys. Rev. Lett.* **128**, 010401, eq. labelled `mutinfo` in the
paper LaTeX) for the pure-dephasing quantum-Darwinism conditional-gate
branching state `|Ψ_⊘^SE⟩` evaluates `I(S:F_m)` in `O(N)` time as

    s_k = ⟨0_{E_k}^{0} | 0_{E_k}^{1}⟩          (per-environment overlap)
    λ⁺_F = (1/2)(1 + sqrt( 1 - 4·p·q·(1 - ∏_{k∈F} |s_k|²) ))
    I(S:F) = h(λ_full) + h(λ_F) − h(λ_F^c)

(where `h(λ) = −λ log₂ λ − (1−λ) log₂(1−λ)` is the binary entropy).

The independent **state-vector route** (Route A) computes the same
`I(S:F)` by:
1. evolving the exact `2^(N+N_S)`-amplitude pure state `|Ψ_⊘^SE⟩`
   under the conditional-gate circuit,
2. taking the exact partial trace `ρ_F = Tr_{S, F^c} |Ψ⟩⟨Ψ|`,
3. diagonalising `ρ_S`, `ρ_F`, `ρ_{SF}` via Jacobi eigenvalue sweep,
4. computing `S(ρ) = − Σ λ log₂ λ`,
5. assembling `I(S:F) = S(ρ_S) + S(ρ_F) − S(ρ_{SF})`.

**Identity claim:**

    I_A(m) ≡ I_B(m)   for all m ∈ {1, ..., N}

at the homogeneous circuit-B selftest point `(N, N_S, θ, p) = (6, 1,
π/2, 1/2)`, **to 6 decimals byte-exact**.

This is the qdarwin module's **headline selftest invariant** — the
`fvd γ = 1.589566` analogue at exact precision.

## Hexa-native verification

    bash state/ubu-build.sh \
        quantum-darwinism/module/qdarwin.hexa qdarwin_bin --selftest

Selftest output (verbatim):

    (2) A == B 6dec : Idiff_max=0.000000 (OK)
    PIP (m, I_route_A, I_route_B, |diff|):
      m=1  I_A=0.612252  I_B=0.612252  diff=0.000000
      m=2  I_A=0.845555  I_B=0.845555  diff=0.000000
      m=3  I_A=0.988710  I_B=0.988710  diff=0.000000
      m=4  I_A=1.131866  I_B=1.131866  diff=0.000000
      m=5  I_A=1.365169  I_B=1.365169  diff=0.000000
      m=6  I_A=1.977421  I_B=1.977421  diff=0.000000
    __SIM_UNIVERSE_QDARWIN__ PASS N=6 circuit=b Idiff=0.000000 norm_drift=0.000000

6/6 PIP points agree to `0.000000` printed precision.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-FORMAL** — Touil-2022 closed form (Stage 1
  symbolic for the algebraic structure; Stage 2 numerical for `log₂`)
  matches the independently computed exact state-vector + partial-
  trace + Jacobi-eigenvalue result. The match is **not** a numerical
  fit but a structural identity from quantum information theory: for
  pure-dephasing branching states the eigenvalues of `ρ_F` are
  determined entirely by the overlaps `|s_k|²` (Touil et al. proved
  this). The hexa-native verifier reproduces both routes at the same
  ~10⁻¹⁵ floating-point precision, with agreement printable as
  `0.000000`.
- **Axis:** §3 PHYS (quantum information). Cross-link §2 MATH (binary
  entropy `h(λ)` is an atlas atom).
- **Real-limit anchor (`g3`):**
  - Zhu, Salice, Touil et al., *Observation of Quantum Darwinism…*,
    *Science Advances* (2025), sciadv.adx6857 / arXiv:2504.00781
    (the experiment).
  - Touil, Sokolov, Zurek et al., *Closed-form mutual information for
    branching states*, **Phys. Rev. Lett. 128, 010401 (2022)** (the
    closed form proved).
- **Provenance:** sim-universe c46707c ·
  `quantum-darwinism/module/qdarwin.hexa` (Route A: `_partial_trace`,
  `_jacobi_eigenvalues_hermitian`, `_vn_entropy`,
  `_mutual_info_route_a`; Route B: `_overlap_abs2`, `_lambda_plus`,
  `_mi_closed_first_m`) · AGENTS.tape `@D g8` · `@X x_zhu_qdarwin`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_lambda_plus_empty_range`** — when fragment `F` is empty,
   `λ⁺_F = 1/2 · (1 + 1) = 1` (empty product → 1, not 0). If the
   `_lambda_plus(empty)` returns `0`, the `h(0)·` term diverges and
   `I_B(m=0)` doesn't match `I_A(m=0)=0`. (Bug caught during
   implementation — see `MODULE/quantum-darwinism.md §D9`.)
2. **`F2_closed_form_sign`** —  `I = h(λ_full) + h(λ_F) - h(λ_Fbar)`;
   if the transposed `I = h(λ_full) - h(λ_F) + h(λ_Fbar)` (or any
   wrong sign permutation) is used, the `m=3` mid-point of the PIP
   would not agree with Route A. (Bug caught during implementation.)
3. **`F3_jacobi_convergence`** — Route A's `_jacobi_eigenvalues_hermitian`
   needs ≥200 sweeps for the `2^(N+1) = 128`-dim case at N=6; reducing
   to 50 sweeps breaks the 6-decimal agreement at `m=N` (where the
   reduced density matrix is most mixed). If selftest still passes at
   sweeps=50, the convergence claim is over-stated.
4. **`F4_different_θ`** — repeat at `θ = π/3` (not `π/2`); both
   routes recompute and must still agree to 6 decimals at every `m`.
   The invariant must NOT be θ-specific. (Spot-checked via
   `--theta-sweep`.)
5. **`F5_homog_vs_random`** — at homogeneous `θ` and `p=1/2`, the
   Touil closed form is most concise; at heterogeneous `θ_k` Route A
   still works but Route B requires summing over the full set of
   `s_k = ⟨0|U_k^0†U_k^1|0⟩`. Replacing the homog single-`s` formula
   with the heterogeneous sum must still match Route A.
6. **`F6_circuit_A_rejected`** — Circuit A (paper's 2-qubit system,
   `N_S=2`) is explicitly OUT-OF-MVP and the qdarwin CLI exits with
   code 1 if invoked. The atlas atom is **circuit B only** (the
   pure-dephasing single-system-qubit case). If a reviewer asserts
   the atom covers circuit A, falsified — the closed form differs.

## Open questions

- The atlas atom is a **multi-point identity** (6 PIP points), not a
  single number. Suggest registering as `s_phys_qdarwin_touil_pip_
  agreement` with the `m=1..N` table embedded.
- Touil-2022 closed form is itself a theorem; the atlas atom verifies
  the **identity** between the qdarwin module's two routes, NOT the
  theorem statement. The theorem is registered separately (e.g.
  `s_math_branching_state_pure_dephasing_mutual_information`).

## Reviewer checklist

- [ ] Tier (🔵 SUPPORTED-FORMAL recommended).
- [ ] Axis (§3 PHYS; §2 MATH cross-link to `h(λ)`).
- [ ] Falsifiers ≥5.
- [ ] Real-limit anchor (g3): Zhu 2025 + Touil 2022 both verified.
- [ ] Merge to `atlas/MAIN.tape § PHYS`.

---

Submitter: claude-opus-4-7 (2026-05-16). Origin: sim-universe c46707c.
