# QFORGE-MOLSCF — log (append-only)

## 2026-06-13 — round-1: lit + design + brick 1 (s-type 1-electron integrals) g5 PASS

NEW domain. Opens QFORGE's molecular SCF front-end gap (cross-cutting handoff b143b899
qfs-r8 → hexa-lang; adjacency f6611b1e, chem #3138): QFORGE had only a periodic plane-wave
SCF (`scf_pw.hexa`, basis `|k+G⟩`), no atom-centered path for finite molecules/atoms/clusters.

### lit (d18 — NOVEL + arxiv both)

- Roothaan 1951 (Rev. Mod. Phys. 23, 69) — RHF matrix eq `F C = S C ε` (non-orthogonal AO basis).
- Szabo & Ostlund, _Modern Quantum Chemistry_ App.A — s-type Gaussian closed forms
  (A.4 product theorem · A.9 overlap · A.11 kinetic · A.33 nuclear · A.41 two-electron).
- Boys 1950 / McMurchie-Davidson 1978 — Gaussian product theorem + Boys `F₀(t)=½√(π/t)·erf(√t)`
  → nuclear V and `(ab|cd)` reuse `stdlib/core/special.erf_fn` (no new special fn).
- Hehre, Stewart & Pople 1969 (STO-3G) — 3-Gaussian Slater-1s fit; brick-1 H 1s primitive set.
- NOVEL probe — end-to-end differentiable HF (arxiv 1711.08127 Tamayo-Mendoza 2018; 2203.04441 2022):
  autodiff through the SCF fixed point gives analytic forces. QFORGE ships `stdlib/autograd` →
  hexa-native MOLSCF can be differentiable from day one (vs Fortran HF bolting AD on after). round-3 lane.

### design

- `drafts/qforge-molscf-round1-design.md` — integrals→RHF SCF→force roadmap + common-core reuse map
  (eigh · erf_fn Boys · autograd force), 7-brick plan, per-brick g5 anchors, three-scale wiring.

### brick 1 (SHIPPED · g5 PASS)

- `stdlib/qforge/molscf/gaussian_integrals.hexa` — s-type Gaussian overlap S_ab + kinetic T_ab,
  closed form (Gaussian product theorem). pub: gint_mu · gint_norm_s · gint_r2 · gint_overlap_s ·
  gint_kinetic_s · gint_overlap_contracted · gint_kinetic_contracted.
- `stdlib/qforge/molscf/gaussian_integrals_selftest.hexa` — 12 checks vs hand-derived analytic anchors.

g5 VERBATIM (HEXA_LANG=. hexa run …gaussian_integrals_selftest.hexa):
    PASS (A) self-overlap a=b=1.2 = 1 (1)
    PASS (A) self-overlap a=b=3.425 = 1 (1)
    PASS (B) prim overlap a=b=1 @1.4 = exp(-0.98) (0.375311)
    PASS (C) STO-3G H2 S_AB @1.4 bohr = 0.6593182001 (0.659318)
    PASS (C) STO-3G H self-overlap ≈ 1 (1)
    PASS (D) kinetic self a=1.5 = 3*(a/2) (2.25)
    PASS (D) kinetic off-center a=b=1 @1.4 (0.195162)
    PASS (E) mu(2,3) = 6/5 (1.2)
    PASS (E) norm_s(1) = (2/pi)^0.75 (0.712705)
    PASS (F) malformed center → 0
    PASS (F) length mismatch contraction → 0
    qforge_molscf_gaussian_integrals_selftest PASS

### honest scope (d6)

round-1 = lit + design + the two s-type one-electron integrals ONLY (closed form, g5-gated against
Szabo & Ostlund analytic values). NOT the full SCF — nuclear V, two-electron (ab|cd), Fock, and the
FC=SCε generalized eigenproblem are round-2+. No fabricated numbers; every target hand-derived.

### round-2 next

1. brick 2 — nuclear attraction V_ab (Boys F₀ via erf_fn, Szabo A.33).
2. brick 3 — two-electron (ab|cd) (Boys F₀, 4-index s-only, Szabo A.41).
3. brick 4 — Fock build F = H_core + G[P].
