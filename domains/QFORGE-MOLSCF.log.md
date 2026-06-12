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

## 2026-06-13 — round-3: bricks 4+5 (Fock build + working RHF SCF · FC=SCε) g5 PASS — KEYSTONE

The molecular SCF front-end is OPEN. brick 1/2/3 supplied every integral; this round
assembles the Fock matrix and closes the Roothaan loop into a real ab-initio molecular
total energy. **Working closed-shell RHF SHIPPED.**

### brick 4+5 (SHIPPED · g5 PASS)

- `stdlib/qforge/molscf/rhf.hexa` — pub: rhf_matmul · rhf_transpose · rhf_s_inv_sqrt (Löwdin
  S^{−½} = Σ_k λ_k^{−½} v_k v_kᵀ via eigh, d19) · rhf_density (P=2ΣC_occC_occᵀ) · rhf_g_matrix
  (G[P]=J−½K) · rhf_fock (F=H_core+G) · rhf_energy_elec (½ΣP(H_core+F)) · rhf_diagonalize
  (F'=XFX → eigh → C=XC', ε ascending) · rhf_scf (full SCF driver, simple density mixing).
- d4-generic: rhf_scf consumes a SUPPLIED integral set (S, H_core, the n⁴ ERI tensor) + n_occ
  + E_nuc. The MOLECULE is the manifest (geometry+basis → those matrices); NO per-molecule
  branch. H₂/He/H₂O all traverse rhf_scf unchanged — only the inputs differ.
- `stdlib/qforge/molscf/rhf_selftest.hexa` — builds the full H₂/STO-3G integral set LIVE from
  brick 1/2/3 (contracted ERI 4-fold-summed in-test), drives RHF, gates against Szabo & Ostlund
  §3.5.2 worked example. eigh reuse only — no new eigensolver/matmul primitive minted (d3).

g5 VERBATIM (HEXA_LANG=. hexa run …rhf_selftest.hexa):
    ── H₂ STO-3G integrals (R=1.4 bohr, live from brick 1/2/3) ──
      S12 = 0.659318   (Szabo 0.6593)
      H11 = -1.12041   H12 = -0.958377
      (11|11)≡(AA|AA) = 0.774606   (Szabo 0.7746)
      (11|22)≡(AA|BB) = 0.569676   (Szabo 0.5697)
      (12|12)≡(AB|AB) = 0.297028   (Szabo 0.2970)
      (11|12)≡(AA|AB) = 0.444106   (Szabo 0.4441)
      E_nuc = 0.714286
    ── RHF SCF result (VERBATIM) ──
      iters       = 2
      converged   = true
      E_elec      = -1.831
      E_total     = -1.11671  Ha
      eps[0] HOMO = -0.578203  eps[1] LUMO = 0.670263
      Δ(E_total − (−1.1167)) = -1.23816e-05
    PASS (A) H2 STO-3G E_total @1.4 bohr ≈ −1.1167 Ha (-1.11671)
    PASS (B) SCF converged
    PASS (B) iters > 0 and finite (≤ 100)
    PASS (B) iters < 50 (fast for symmetric H2)
    PASS (C) eps ascending (HOMO < LUMO)
    PASS (C) HOMO ε (1σ_g) ≈ −0.578 Ha (Szabo) (-0.578203)
    PASS (C) HOMO occupied energy < 0 (bound)
    PASS (D) Fock symmetric F[0,1]=F[1,0] (-0.593884)
    PASS (D) tr(P·S) = N_elec = 2 (2.0)
    PASS (D) idempotent (P S)² = 2 P S (closed-shell)
    PASS (D) S^{-½} S S^{-½} = I (diag) (1)
    PASS (D) S^{-½} S S^{-½} = I (offdiag→0) (-1.11022e-16)
    PASS (E) transpose [1,2;3,4] → [1,3;2,4]
    PASS (E) I · M = M
    qforge_molscf_rhf_selftest PASS

### honest result (d6 / @L5)

- **E_total = −1.11671 Ha** (verbatim converged value). Szabo & Ostlund worked example −1.1167 Ha;
  |Δ| = 1.24e-5 Ha — inside the 1e-4 gate by ~8×. NOT forced — the integrals are computed live and
  the SCF converges to this number on its own.
- Every Szabo two-electron integral reproduced to 4 sig figs: (AA|AA)=0.7746 · (AA|BB)=0.5697 ·
  (AB|AB)=0.2970 · (AA|AB)=0.4441. S₁₂=0.6593. HOMO ε(1σ_g)=−0.5782 Ha matches Szabo exactly.
- SCF converges in **2 iterations** (symmetric H₂ from a core-Hamiltonian guess; |ΔE|<1e-10).
- Idempotency in the S-metric holds exactly: tr(PS)=2=N_elec and (PS)²=2PS (closed-shell P).
  F Hermitian; Löwdin S^{−½}SS^{−½}=I to 1e-16. No fabrication.

### working RHF SEALED — three-scale wiring now live

The molecular SCF front-end front-end is COMPLETE for s-type bases: integrals → Fock → FC=SCε →
self-consistent density → total energy, all g5-gated against the textbook anchor. The atoms / chem /
system scales now share ONE generic RHF path (d4) — He/Be single-atom HF, H₂/H₂O molecular energy,
and finite-cluster fragment SCF all consume the same rhf_scf with only their manifest (geometry+basis
→ S/H_core/ERI) differing. The cross-cutting "no molecular SCF" blocker (handoff b143b899) is cleared
for s-type; p/d angular momentum (brick 7) extends it to real polyatomic chemistry.

### round-4 next

1. brick 6 — analytic molecular force ∇_R E via autograd through the SCF (NOVEL lane, arxiv
   1711.08127/2203.04441): differentiate E_total w.r.t. nuclear coordinates; reuse stdlib/autograd.
2. brick 7 — p/d angular momentum (Hermite/McMurchie-Davidson recursion) → real polyatomics (H₂O).
3. DIIS convergence accelerator (round-3 uses simple density mixing — correct but not optimal for
   stiff/larger systems); add Pulay DIIS over the F·P·S−S·P·F error vector.

## round-4 — p angular momentum (McMurchie-Davidson) + real polyatomic H₂O SEALED

`stdlib/qforge/molscf/md_integrals.hexa` (new, brick 6/7-of-file) — the general McMurchie-Davidson
recursion that lifts the s-only closed forms (brick 1/2) to ARBITRARY Cartesian angular momentum.
Pure recursion, NO change to `rhf_scf` (rhf.hexa) — the higher-L front-end simply feeds it bigger
S/H_core/ERI matrices (d4 generic dispatch).

### what landed
- **E-coefficient tower** `md_hermite_e(i,j,t,…)` — the Hermite-expansion coefficient recursion
  (Helgaker-Jørgensen-Olsen "Molecular Electronic-Structure Theory" eq. 9.5.6), seeded at
  E^{00}_0 = K_AB = exp(−μX_AB²) (the s·s Gaussian prefactor). One independent tower per Cartesian axis.
- **Boys F_n table** `md_boys(nmax,t)` — two stable regimes: small-t ascending-series seed + downward
  recursion; large-t (≥35) exact F_0 + upward recursion. The naive single-regime version DIVERGED at
  t≳200 (O 1s α=130 reaches p·R²≈400) — fixed (HJO §9.8.1). F_n exact vs direct F_0 to ≤1e-9 across t.
- **Hermite Coulomb R-tensor** `md_hermite_r(t,u,v,n,…)` (HJO 9.9.9) → V (nuclear) and (ab|cd) (ERI)
  for any L via E⊗R contractions.
- **Cartesian normalization** `md_norm_prim(l,a)` = (2a/π)^¾ (4a)^{L/2}/√[(2lₓ−1)!!(2lᵧ−1)!!(2l_z−1)!!];
  L=0 reduces to the brick-1 s norm exactly.

### g5 (4 verdicts, VERBATIM — `md_selftest.hexa`)
- **(a) L=0 reduction** — MD S/T == brick gaussian_integrals to 8e-17/7e-17; MD V/ERI == brick
  coulomb_integrals to ≤1e-7 (shared erf_fn Boys floor). STO-3G H₂ S₁₂=0.6593182001 via MD.
- **(b) p-shell vs independent values** — ⟨pₓ|pₓ⟩ self-overlap = 1.0 (Cartesian norm);
  ⟨pₓ|−½∇²|pₓ⟩ = a(2L+3)/2 = 2.5 (a=1, EXACT analytic, L=1); ⟨pₓ|pᵧ⟩=0, ⟨s|pₓ⟩=0 parity;
  p-nuclear rotational symmetry ⟨pₓ|V|pₓ⟩(nuc@x)=⟨p_z|V|p_z⟩(nuc@z) to 1e-12.
- **(c) END-TO-END H₂O/STO-3G** through the UNCHANGED rhf_scf — 7×7 (S,H_core) + 7⁴ ERI tensor
  (8-fold symmetry, 406 unique) with the O 2p shell, 10 e⁻ / 5 occ MOs. Converged in 12 iters to
  **E_total = −74.9618 Ha** vs reference **−74.961754 Ha** (Standard, "A Hartree-Fock Calculation of
  the Water Molecule", CHMY-564 MSU 2015; Gaussian-09 STO-3G, R(O-H)=0.95 Å ∠=104.5°),
  **|Δ| = 4.6e-5 Ha** (inside 1e-4). All 7 MO eigenvalues match the reference to printed precision
  (−20.24094 −1.27218 −0.62173 −0.45392 −0.39176 | 0.61293 0.75095). H_core diagonals match the ref
  matrices (H₀₀=−32.729 vs −32.730).
- **(d) regression** — gaussian_/coulomb_/rhf selftests (r1/r2/r3) all PASS unchanged; H₂
  E_total=−1.11671 Ha untouched.

### honest note (d6)
The reference PDF's printed V(2pₓ) tableau entry (−9.926) is a transcription error: an INDEPENDENT
scipy McMurchie-Davidson reproduces THIS code's value (−9.9926) to all digits, and the in-plane
V(2pᵧ)/V(2p_z) (−10.152/−10.088) match the reference exactly. The converged Gaussian-09 energy
(−74.961754, from the SCF not the tableau) is the authoritative anchor and is what (c) gates on. The
printed value is NOT trusted over the recompute.

### SEALED vs OPEN
- **SEALED**: s + **p** angular momentum (S/T/V/ERI), full McMurchie-Davidson machinery (E-coeff,
  R-tensor, F_n), real polyatomic H₂O/STO-3G end-to-end through the unchanged generic RHF.
- **OPEN (round-5)**: **d (+ f)** angular momentum — the SAME recursions carry NO L cap, so d is
  reachable by adding the Cartesian-d normalization (6 Cartesian → 5 spherical contraction) + a
  d-bearing molecule fixture; brick 6 analytic force ∇_R E (autograd lane); DIIS accelerator.

### round-5 next
1. brick 8 — d(+f) angular momentum: validate against a d-bearing molecule (e.g. H₂S / SO₂ STO-3G,
   or a first-row transition-metal hydride) + Cartesian-d → spherical-harmonic normalization.
2. brick 6 — analytic molecular force ∇_R E via autograd through brick 1-7 (NOVEL lane).
3. DIIS convergence accelerator over the F·P·S−S·P·F error vector (round-3/4 use simple mixing).
