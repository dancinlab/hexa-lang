# Differentiable-DFT reverse-mode LR for QFORGE — grounded design

**Milestone**: QFORGE-PERF · 🧠 LANE C · `differentiable-DFT reverse-mode LR`
**Status**: ⚪ research-grounded (NOT closed). Tractable **tail** verified g5
(`bench/qforge/adjoint_a2f_lambda_tc.hexa`, `VERDICT_ADJOINT_A2F=MATCH`); the full
adjoint through the SCF + Sternheimer fixed points is a multi-module paradigm
build whose design is grounded here per CLAUDE.md d6 (no false closure).

## 0. Goal

Replace finite-difference + forward Sternheimer with reverse-mode AD so that
el-ph derivatives ∂(λ, Tc)/∂(structure, U, pseudopotential params) come out
analytically and cheaply: **one adjoint sweep returns the WHOLE gradient vector**,
versus N_param forward re-evaluations of the α²F→Tc map (the cost that drives the
inverse-design / structure-search loop in `dtc_dstruct` and `inverse_design`).

## 1. The chain and where it is / is not differentiable today

```
 (structure x, U, pseudo p)
        │  ∂ρ/∂x          ← adjoint of SCF fixed point      (NEEDS adjoint)
        ▼
   converged ρ, ψ, ε
        │  ∂ψ'/∂x         ← adjoint of Sternheimer LR solve (NEEDS adjoint)
        ▼
   screened dV, |g|²(k,q,ν)   = α²F samples              (DFPT output)
        │  ∂λ/∂α²F  , ∂ω_log/∂α²F   ← trapezoid quadrature  ✅ VERIFIED (g5)
        ▼
   λ , ω_log , ω̄₂
        │  ∂Tc/∂λ , ∂Tc/∂ω_log     ← Allen-Dynes algebra    ✅ VERIFIED (dtc_dstruct g5)
        ▼
        Tc
```

| chain piece | form | differentiable today? | home |
|---|---|---|---|
| Tc(λ,ω_log,ω̄₂) Allen-Dynes | closed-form algebra | ✅ exact analytic, g5 | `stdlib/qforge/dtc_dstruct` (∂Tc/∂λ, ∂Tc/∂ω_log) |
| λ = 2∫α²F/ω dω | trapezoid quadrature | ✅ exact analytic, g5 (this PR) | `bench/qforge/adjoint_a2f_lambda_tc` |
| ω_log = exp((2/λ)∫(α²F/ω)lnω dω) | trapezoid + exp | ✅ exact analytic, g5 (this PR) | this PR |
| ω̄₂ = √((2/λ)∫α²F·ω dω) | trapezoid + sqrt | identical quadrature form (held out, named) | (extend this PR) |
| α²F ← |g|², ε, δ-FS sum | weighted bilinear sum | analytically differentiable (assembler bilinear) | `stdlib/qforge/assembler` |
| ψ' ← Sternheimer (H−ε)ψ'=−P_c δV ψ | linear solve, fixed point | **NEEDS adjoint** (this design) | `stdlib/qforge/sternheimer` |
| ρ ← SCF (self-consistent V[ρ]) | nonlinear fixed point | **NEEDS adjoint** (this design) | `stdlib/qforge/scf` |

**Verified now (tail)**: every piece from the α²F samples (the DFPT output) down
to Tc. This is the entire algebraic + quadrature tail — what was "already
differentiable closed-forms" per d19, now made an *explicit reverse-mode adjoint*
and checked against FD to ≈1e-9.

**Remaining (head)**: the two fixed points — SCF and Sternheimer. These are the
real paradigm build; their adjoints are designed below.

## 2. Adjoint of the Sternheimer linear-response solve

Forward (per perturbation, per occupied state, projected CG):
```
   (H_SCF − ε_n) |ψ'_n⟩ = − P_c  δ^{x}V_SCF  |ψ_n⟩          (A)
```
with P_c = 1 − Σ_occ|ψ⟩⟨ψ| the conduction projector. Write the operator
M = P_c (H_SCF − ε_n) P_c. The forward solve is M ψ' = b, b = −P_c δV ψ.

**Adjoint**: M is Hermitian (H_SCF Hermitian, P_c a projector), so M† = M. For a
downstream scalar L with seed ψ̄' = ∂L/∂ψ', the input adjoints are obtained by
ONE solve of the SAME operator (the self-adjoint advantage — no transposed
factorization, reuse the verified projected-CG `qforge_sternheimer`):
```
   M λ_adj = ψ̄'                                              (B)
   b̄ = λ_adj                  →  δV̄ ψ-contribution
   M̄ contributes  −λ_adj ψ'†  (the ε_n / H_SCF sensitivity)
```
i.e. the adjoint of a self-adjoint linear solve is the SAME solve on the adjoint
seed (implicit-function-theorem at the linear fixed point — Blondel et al. 2022;
implicit-layers tutorial Ch.2). **Cost = 1 extra projected-CG per seed**, vs the
forward solve QFORGE already runs (`sternheimer_selftest` machine-precision
parity is the correctness anchor the adjoint reuses). The 2n+1 theorem
(Gonze-Vigneron 1989; Giustino RMP 2017 §IV.B, Eqs. ~46–60) guarantees the
first-order response suffices for the second-order (force-constant / |g|²)
derivatives — so no higher-order response solve is needed for ∂α²F/∂x.

## 3. Adjoint of the SCF fixed point (implicit-function-theorem)

The converged density solves the fixed point ρ = F(ρ, x) where F is one
KS step (build V[ρ], diagonalize, re-occupy). At the converged ρ*:
```
   (I − ∂F/∂ρ) ρ̄_in = ∂F/∂ρ|_explicit · (downstream seed)
```
Reverse-mode pulls the downstream adjoint ρ̄ back through (I − J_ρ)^{−T} where
J_ρ = ∂F/∂ρ is the SCF response operator (the same dielectric/Jacobian the DIIS
mixer `qforge_anderson_next` already approximates). Two hexa-native routes:

- **(a) Neumann / fixed-point adjoint**: solve (I − J_ρ^T) z = ρ̄ by the SAME
  iteration as the forward SCF (a few mat-vecs of J_ρ^T, each = one linearized KS
  step). Converges at the SCF convergence rate — reuse the Anderson/Pulay
  acceleration already wired in `scf.hexa` (`and_depth>0` branch). This is the
  competitive_recurrence / "differentiate through the fixed point cheaply"
  result (Christianson 1994; Blondel JAXopt 2022; npj Comput. Mater. 2025
  s41524-025-01880-3 §implicit-diff). **No unrolling of SCF iterations** → O(1)
  memory in the iteration count (the reverse-mode win over FD + naive autodiff).
- **(b) Dielectric-matrix adjoint**: J_ρ = χ·v (irreducible response × Coulomb);
  the same screened-response machinery in `screening.hexa` / `screened_dv.hexa`
  supplies the action of J_ρ. Reuse, do not rebuild (d3/d19).

## 4. hexa-native AD substrate

hexa has no general reverse-mode AD tape today, so the design is **structured
adjoints** (hand-derived per kernel, each g5-checked vs FD) rather than a generic
tape — exactly the pattern this PR ships for the tail. Each kernel exposes a
forward + a pullback; the pullbacks compose by the chain rule. This mirrors how
production differentiable-DFT codes (DFTK.jl + ForwardDiff/implicit; Jrystal;
Grad-DFT; QEX) wrap structured adjoints around the SCF/response solves rather than
naively unrolling. A generic hexa AD tape (`self/ml`) would later subsume the
hand-pullbacks; until then, structured adjoints are the honest, verifiable path.

## 5. Falsifier (board contract) & closure criteria

Milestone falsifier: **AD-gradient == finite-diff response (tol) ∧ Sternheimer-call
removed**.
- Tail (✅ met this PR): ∂λ/∂α²F and ∂Tc/∂α²F match FD to ≈1e-9; no FD over the
  tail. The Sternheimer call is NOT yet removed (the head still uses forward DFPT)
  → milestone stays **[ ]** (⚪ grounded), not flipped.
- Head closure (future): implement §2 + §3 adjoints, verify ∂α²F/∂x_adjoint vs FD
  ∂α²F/∂x on a small fixture (Al/Nb fcc, the `*_elph_xval_test` cells), and show
  the forward-Sternheimer-per-perturbation sweep is replaced by ONE adjoint solve.
  That is when `differentiable-DFT reverse-mode LR` flips to closed.

## 6. Citations

- Giustino, *Electron-phonon interactions from first principles*, **Rev. Mod.
  Phys. 89, 015003 (2017)** — DFPT/Sternheimer LR, §IV response derivatives,
  2n+1 theorem. arXiv:1603.06965.
- Gonze & Vigneron, *Density-functional approach to nonlinear-response
  coefficients of solids*, **Phys. Rev. B 39, 13120 (1989)** — 2n+1 / variational
  DFPT.
- Baroni, de Gironcoli, Dal Corso, Giannozzi, *Phonons and related crystal
  properties from DFPT*, **Rev. Mod. Phys. 73, 515 (2001)** — Sternheimer eq.
- Herbst, Levitt et al., *Algorithmic differentiation for plane-wave DFT:
  materials design, error control and learning model parameters*, **npj Comput.
  Mater. (2025), s41524-025-01880-3** (arXiv:2509.07785) — implicit-function-
  theorem differentiation through the SCF fixed point; reverse-mode for
  high-dimensional gradients named as the extension.
- Blondel et al., *Efficient and modular implicit differentiation*, **NeurIPS
  2022** (JAXopt) — adjoint of a fixed point / linear solve.
- Christianson, *Reverse accumulation and attractive fixed points*, **Optim.
  Methods Softw. 3, 311 (1994)** — fixed-point reverse-mode without unrolling.
- Kasim & Vinko, *Grad-DFT / differentiable DFT*, arXiv:2106.... ; Jrystal;
  QEX — structured-adjoint differentiable-DFT precedent.
- Carbotte, **Rev. Mod. Phys. 62, 1027 (1990)** — λ, ω_log moment definitions
  (the verified tail); Allen & Dynes, **Phys. Rev. B 12, 905 (1975)**.

## 7. Honest scope (d6)

What is **verified** (g5, this PR): the reverse-mode adjoint of the α²F→λ→Tc
closed-form tail — the differentiable part QFORGE already had as forward
closed-forms, now an explicit, FD-checked reverse-mode pullback (∂λ/∂α²F,
∂ω_log/∂α²F, composed ∂Tc/∂α²F). What is **designed but NOT built/closed**: the
adjoints of the SCF and Sternheimer fixed points (§2–§3). Therefore the milestone
is **research-grounded (⚪)**, not closed — a grounded design + a verified tail
gradient, no forced number.
