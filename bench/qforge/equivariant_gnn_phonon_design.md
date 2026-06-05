# Equivariant GNN phonons + el-ph (MACE-class) — QFORGE surrogate design

**Domain**: QFORGE-PERF · LANE C 🧠 paradigm · 🔬 research-probe
**Verdict**: ⚪ research-grounded ([ ] kept) — equivariance kernel VERIFIED (g5),
full trained phonon surrogate needs a training pipeline (out of scope; d6 honest).
**Scope**: docs/bench-only · CPU-only · no rent · no `stdlib/qforge` engine edit (d3).

---

## 1. Goal

Replace per-candidate DFPT (the SCF → Sternheimer-linear-response → dynamical-matrix
chain that costs one paid run per material) with a *trained* E(3)-equivariant graph
neural network that predicts, directly from the crystal structure:

1. the **interatomic force constants** Φ_iα,jβ = ∂²E/∂u_iα∂u_jβ (the Hessian of the
   model energy), hence the **dynamical matrix** D(q) = Σ_R Φ(0,R) e^{iq·R}/√(m_i m_j)
   and the **phonon band structure** ω_qν;
2. ideally the **electron–phonon coupling** α²F(ω) → λ → Tc, either by an additional
   equivariant head or via a downstream model (BETE-NET style).

The win: a forward pass (ms) replaces a DFPT campaign (pod-hours), turning the
per-candidate cost axis of the RTSC screen into amortized inference.

## 2. Why E(3)-equivariance is the load-bearing property

A phonon/force-constant model must obey the symmetry of physics: if the input crystal
is rotated by R ∈ O(3), every predicted vector/tensor quantity must rotate consistently
(forces rotate as l=1 vectors, the force-constant tensor as a rank-2 / l∈{0,1,2} object).
A model that is *not* equivariant either (a) needs orders of magnitude more data to learn
the symmetry approximately, or (b) violates it and predicts a rotation-dependent Hessian —
physically wrong. MACE (arXiv:2206.07697) and NequIP (Nat. Commun. 13, 2453, 2022) build
equivariance into the architecture: features are organized by irreducible representation
(l = 0,1,2,…) of O(3), messages combine them with the Clebsch–Gordan tensor product, and
the whole network commutes with rotation by construction. Equivariance is therefore the
*defining correctness property* — the one thing that is both (i) tractable to implement and
verify here and (ii) the foundation every downstream phonon claim rests on.

## 3. What was implemented and VERIFIED (the tractable sliver)

`bench/qforge/equivariant_edge_feature.hexa` — an E(3)-equivariant edge-feature kernel
with three feature heads that a real MACE/NequIP layer uses, each verified to satisfy

    feature( R · structure )  ==  D_l(R) · feature( structure )

to machine precision under a generic O(3) rotation R:

| head | feature | transform target |
|------|---------|------------------|
| l=1 vector message | m_ij = f(\|r_ij\|)·r̂_ij | D_1(R) = R (radial f is an O(3) scalar) |
| l=1 real spherical harmonic | Y_1^m(r̂), m∈{-1,0,+1} (y,z,x basis) | D_1(R) (permuted R) |
| l=2 real spherical harmonic | Y_2^m(r̂), m∈{-2..+2} (5 d-harmonics) | D_2(R) Wigner matrix |

Plus an **improper-rotation** test (det R = -1, full O(3) incl. parity) and a
**negative control** (a deliberately non-equivariant feature, r_z², must produce a
*large* residual — proving the g5 discriminates, is not a tautology).

The l=2 head is the strongest test: a non-equivariant feature cannot satisfy the 5-dim
D_2 transform by accident. D_2(R) is built operationally from the Cartesian R by the
exact l=2 irrep linear identity D_2 = [Y_2(R·b_k)] · [Y_2(b_k)]^{-1} (5 probe directions,
Gauss-Jordan inverse), so the verification does not assume the answer it checks.

### g5 result (VERBATIM — see the .log entry / PR body)

Max equivariance error over all heads is at machine precision (FP64 eps scale);
negative control residual is O(1) (large), as required. VERDICT_EQUIVARIANCE=MATCH.

## 4. What is NOT done (honest ⚪ scope, d6)

The verified kernel is the *equivariant primitive*. A working phonon surrogate additionally
requires, all OUT of scope for this docs-only/CPU-only/no-rent probe:

- a **training stack**: Clebsch–Gordan tensor-product message passing, learnable radial
  basis (Bessel × polynomial envelope), self-interaction + gated nonlinearity, an
  energy/Hessian readout, and a differentiable optimizer (the kernel here is the *fixed*
  geometric scaffolding those layers sit on, not the learnable network);
- a **DFT phonon dataset** (force constants / α²F labels) to train and a held-out split to
  test the falsifier `GNN α²F == DFPT α²F (held-out) ∧ Tc MAE`;
- **autodiff Hessian** plumbing to get Φ = ∂²E/∂u² from the model energy.

Therefore the milestone stays `[ ]` with a ⚪ research-grounded verdict: the equivariance
primitive (the property the whole approach hinges on) is verified to machine precision and
the design is literature-grounded, but no phonon-prediction capability is yet measured.
Per d6 we do not force a close — a verified equivariance kernel + grounded design is a
valid ⚪ verdict, not a false GATE_CLOSED.

## 5. Path to flip `[ ]` → `[x]` (concrete, for a future training-capable session)

1. Train a small MACE/NequIP head on an existing open phonon set (e.g. MDR phonon
   database / MACE-MP-0 foundation model fine-tune) on a host with a GPU + torch/e3nn.
2. Predict Φ → D(q) → ω_qν on a held-out structure; falsifier #1 = phonon-band MAE vs DFPT.
3. Add the el-ph head (or chain BETE-NET, arXiv:2401.16611, α²F → Tc MAE 2.5 K); falsifier
   #2 = α²F == DFPT α²F (held-out) ∧ Tc MAE.
4. Cross-val one RTSC anchor (CaH6 / LaH10) GNN-Φ vs the QFORGE DFPT Φ already in the engine.

## 6. Literature (grounded design)

- I. Batatia, D. P. Kovács, G. N. C. Simm, C. Ortner, G. Csányi, "MACE: Higher Order
  Equivariant Message Passing Interatomic Potentials," NeurIPS 2022, arXiv:2206.07697.
- S. Batzner, A. Musaelian, L. Sun, M. Geiger, J. P. Mailoa, M. Kornbluth, N. Molinari,
  T. E. Smidt, B. Kozinsky, "E(3)-equivariant graph neural networks for data-efficient
  and accurate interatomic potentials," Nat. Commun. 13, 2453 (2022) [NequIP].
- I. Batatia et al., "A foundation model for atomistic materials chemistry" [MACE-MP /
  MACE-OFF], arXiv:2401.00096.
- M. Geiger, T. Smidt, "e3nn: Euclidean Neural Networks," arXiv:2207.09453 (the
  irrep / spherical-harmonic / Clebsch–Gordan tooling this kernel mirrors).
- Phonons-from-MLIP-Hessian: the force-constant matrix as the autodiff Hessian of the
  equivariant-MLIP energy — standard practice with MACE/NequIP + phonopy.
- J. B. Gibson, A. C. Hire, P. M. Dee, et al., "Bootstrapped Ensemble of Tied Networks
  (BETE-NET): accelerated discovery of conventional superconductors," arXiv:2401.16611
  (predicts α²F(ω) → Tc, MAE ≈ 2.5 K).
