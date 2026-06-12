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

## 2026-06-13 — round-2: bricks 2+3 (Coulomb integrals — Boys F₀, V_ab, (ab|cd)) g5 PASS

The two Coulomb (1/r₁₂-bearing) integrals that complete the RHF Fock inputs. Both
reduce to ONE special function, the Boys F₀, so they live in one brick.

### lit anchor (Szabo & Ostlund App.A)

- A.32 — Boys `F₀(t) = ∫₀¹ exp(−t u²) du = ½√(π/t)·erf(√t)`, `F₀(0)=1` (t→0 limit).
- A.33 — nuclear attraction `V_ab = −(2π/p)·Z·N_aN_b·exp(−μ|A−B|²)·F₀(p|P−C|²)`.
- A.41 — two-electron `(ab|cd) = 2π^{5/2}/(p q √(p+q))·ΠN·exp(−μ_ab R_ab²)exp(−μ_cd R_cd²)·F₀((pq/(p+q))|P−Q|²)`.
- reuse (d19/d3): `core/special.erf_fn` (A&S 7.1.26) is the ONLY transcendental; measured
  Boys F₀ accuracy ≲2.5e-7 across t → 1e-6 gate met with margin (not tolerance-tuned).
  `F₀(0)=1` returned exactly (erf rational ~1.8e-6 off at 0; limit special-cased).

### bricks 2+3 (SHIPPED · g5 PASS)

- `stdlib/qforge/molscf/coulomb_integrals.hexa` — pub: boys_f0 · cint_norm_s · cint_r2 ·
  cint_product_center · cint_nuclear_s · cint_eri_s · cint_nuclear_contracted. d4-generic
  (every integral one path; instance = exponent/center/charge args, no name hardcoding).
- `stdlib/qforge/molscf/coulomb_integrals_selftest.hexa` — 25 checks vs hand-derived analytic
  values + EXACT point-charge limits (no fabrication).

g5 VERBATIM (HEXA_LANG=. hexa run …coulomb_integrals_selftest.hexa):
    PASS (A) F0(0) = 1 (exact limit) (1.0)
    PASS (A) F0(1e-15) → 1 limit (1.0)
    PASS (A) F0(1) = 0.7468241328 (0.746824)
    PASS (A) F0(0.5) = 0.8556243919 (0.855624)
    PASS (A) F0(2) = 0.5981440067 (0.598144)
    PASS (A) F0 monotone: F0(0.5) > F0(2)
    PASS (B) V self a=1 Z=1 nuc@center = −2√(2/π) (-1.59577)
    PASS (B) V self a=0.8 Z=6 = −2·6·√(1.6/π) (-8.5638)
    PASS (B) STO-3G H single-center V(nuc@A) = −1.2266137219 (-1.22661)
    PASS (B) V attractive (<0)
    PASS (C) (aa|aa) a=0.8 = 2√(a/π) (1.00925)
    PASS (C) (ab|ab) = (ba|ba) symmetry (0.483044)
    PASS (C) (ab|cd) = (cd|ab) bra↔ket (0.432279)
    PASS (C) (aa|aa) repulsive (>0)
    PASS (D) V nuc@R=5 → −Z/R = −0.2 (-0.2)
    PASS (D) V Z=3 nuc@R=50 → −0.06 (-0.06)
    PASS (D) (aa|bb) R=5 → 1/R = 0.2 (0.2)
    PASS (D) (aa|bb) R=20 → 1/R = 0.05 (0.05)
    PASS (D) |V| decays with R: |V(5)| > |V(10)|
    PASS (E) V malformed center → 0
    PASS (E) V malformed nucleus → 0
    PASS (E) ERI malformed center → 0
    PASS (E) F0 negative arg guarded → 1
    PASS (E) nuclear length-mismatch contraction → 0
    qforge_molscf_coulomb_integrals_selftest PASS

### honest scope (d6)

round-2 = the two Coulomb integrals (V_ab, (ab|cd)) for s primitives ONLY, closed form, g5-gated
against Szabo & Ostlund analytic values + exact 1/R / −Z/R point-charge limits. NOT yet the SCF.
The far-limit checks are the strongest anchors: as separation → ∞ the Gaussian charge clouds become
point-like, so V → −Z/R and (aa|bb) → 1/R EXACTLY (matched to 1e-9). No fabricated numbers.

### remaining to a working RHF (round-3)

With S, T (brick 1) + V_ab, (ab|cd) (brick 2+3), all integral inputs exist. Remaining:
1. brick 4 — Fock build F = H_core + G[P], H_core = T + V_nuc (sum over nuclei),
   G[P]_μν = Σ_λσ P_λσ [ (μν|σλ) − ½(μλ|σν) ] (RHF Coulomb − ½ exchange).
2. brick 5 — RHF SCF loop FC=SCε: S^{−½} orthogonalization → diagonalize F' (reuse eigh/eigen.hexa)
   → build P from occupied MOs → iterate to density convergence. g5 anchor: H₂/STO-3G @1.4 bohr
   E_total ≈ −1.1167 Ha (Szabo & Ostlund worked example).

### round-3 next

1. brick 4 — Fock build (H_core = T+V, G[P] = J − ½K from the (ab|cd) tensor).
2. brick 5 — RHF SCF FC=SCε loop (S^{−½} + eigh + density iteration), H₂/STO-3G E≈−1.1167 Ha g5.
3. (then) brick 6 — analytic force ∇_R E via autograd (NOVEL lane); brick 7 — p/d angular momentum.
