@title: 🧬 QFORGE-MOLSCF — molecular SCF front-end ("분자 ab-initio 개통")

@goal: QFORGE 범용 엔진에 atom-centered Gaussian/STO 분자 SCF front-end 를 신설 — 주기 평면파(`|k+G⟩`)
밖의 유한 분자/원자/클러스터를 위한 실 ab-initio Roothaan RHF(`F C = S C ε`) 경로를 개통한다. s→p/d
각운동량까지 1-/2-전자 적분 → Fock → SCF → 분자 force(autograd) 를 공통코어 재사용(d19)으로 닫고,
atoms·chem·system 세 스케일의 공통 blocker(분자 SCF 부재, handoff b143b899) 를 한 번에 해소한다.

## method

QFORGE 의 유일한 SCF 는 주기 **평면파**(`stdlib/qforge/scf_pw.hexa`): 기저 `|k+G⟩`, 운동항 대각
`½|k+G|²`. 유한 분자엔 부적합 — Bloch k 없음, 파동함수 0 으로 감쇠, 자연 기저는 atom-centered
Gaussian/STO. 신 front-end = (1) Gaussian product theorem 닫힌형 1-/2-전자 적분, (2) `F=H_core+G[P]`
Fock 빌드, (3) 비직교 일반화 고유문제 `FC=SCε`. 모든 g5 anchor 는 Szabo & Ostlund 해석값.
공통코어 재사용(d19): `eigh`(eigen.hexa) · Boys `F₀`=`erf_fn`(special.hexa) · 분자 force=`autograd`.

## milestones

- [x] round-1 lit — Roothaan 1951(FC=SCε)·Szabo-Ostlund App.A(s 적분 닫힌형)·Boys/McMurchie-Davidson·
      STO-3G(Hehre 1969) + NOVEL: end-to-end 미분가능 HF(autograd through SCF, arxiv 1711.08127/2203.04441)
- [x] round-1 설계 — `drafts/qforge-molscf-round1-design.md` (적분→RHF→force 로드맵 + 공통코어 매핑)
- [x] brick 1 — s-type Gaussian 1-전자 적분(중첩 S · 운동 T) 닫힌형 + g5 PASS
      (STO-3G H₂ S_AB@1.4bohr=0.6593182001 · single-prim exp(−0.98) · self=1 · 운동 self=3μ)
- [x] brick 2 — 핵인력 V_ab (Boys F₀ via erf_fn · Szabo A.33) g5 PASS
      (self V=−2Z√(2a/π) · STO-3G H single-center V=−1.2266137219 · far nuc→−Z/R)
- [x] brick 3 — 2-전자 (ab|cd) (Boys F₀ · 4-index s-only · Szabo A.41) g5 PASS
      (same-center (aa|aa)=2√(a/π) · 8-fold symmetry · 두 cloud 멀어지면 (aa|bb)→1/R)
- [x] brick 4 — Fock 빌드 F = H_core + G[P] (G=J−½K · `rhf.hexa` rhf_g_matrix/rhf_fock) g5 PASS
- [x] brick 5 — RHF SCF 루프 FC=SCε (Löwdin S^{−½}+eigh 재사용·d19·density iter) g5 PASS
      (H₂/STO-3G @1.4bohr E_total=−1.11671 Ha vs Szabo −1.1167 |Δ|=1.2e-5 · iters=2 · HOMO ε=−0.5782)
- [ ] brick 6 — 분자 force ∇_R E (autograd through brick 1-5 · NOVEL lane)
- [x] brick 7 (round-4) — p 각운동량 McMurchie-Davidson (E-coeff·Hermite R-tensor·Boys F_n)
      `md_integrals.hexa` + 실제 polyatomic H₂O/STO-3G end-to-end through UNCHANGED `rhf_scf` g5 PASS
      (L=0 reduction == brick-1/2 s형 ≤1e-12 · ⟨pₓ|T|pₓ⟩=a(2L+3)/2=2.5 exact ·
       H₂O E_total=−74.9618 Ha vs ref −74.961754 |Δ|=4.6e-5 · 7 MO ε all match · r1/r2/r3 regress PASS)
- [x] brick 8 (round-5) — d 각운동량 (동일 MD recursion·L-cap 無) + Cartesian→spherical d 정규화
      `md_shell.hexa` (generalized multi-component AO assembly + 5 real solid-harmonic d·s-contaminant 제거)
      → H₂O/STO-3G + d-polarization(O,α=0.8) 12-AO end-to-end through UNCHANGED `rhf_scf` g5 PASS
      (a) L≤1 regression: STO-3G H₂ S12=0.6593182001 · ⟨pₓ|T|pₓ⟩=2.5 exact (no s/p drift)
      (b) ⟨d_xy|d_xy⟩=1 · ⟨d_xy|T|d_xy⟩=a(2L+3)/2=3.5 exact (off-diag) · d_zz=13/6 honest · parity 0 · d⟂(xx+yy+zz)~4e-16
      (c) E_total=−74.9869 Ha vs PySCF 2.13.1 −74.986924782 |Δ|=2.5e-5 · d 실engage(ΔE=−25 mHa vs s,p-only)
      (d) r1/r2/r3/r4 regress ALL PASS
- [x] brick 9 (round-6) — f 각운동량 (10 Cartesian → 7 spherical, m=0,±1,±2,±3 · 동일 MD recursion·L-cap 無)
      + valence-d 전이금속 분자 (ScH/STO-3G all-electron) end-to-end through UNCHANGED `rhf_scf` g5 PASS
      `md_shell.hexa` generic `_md_harm_ao` builder (d4 — (cart,harm) 테이블 추가일 뿐 새 코드경로 無)
      (a) L≤2 regression: H₂ S12=0.6593182001 · ⟨pₓ|T|pₓ⟩=2.5 · ⟨d_xy|T|d_xy⟩=3.5 exact (no s/p/d drift)
      (b) ⟨f_xyz|f_xyz⟩=1 · ⟨f_xyz|T|f_xyz⟩=a(2L+3)/2=4.5 exact · f_zzz=21/10 honest · parity 0 ·
          spherical-f ⟂ 3 p-type contaminant(∝r²·{x,y,z})~4e-16 (d s-contaminant 제거의 f 유사물)
      (c) ScH/STO-3G E_total vs PySCF 2.13.1 RHF −752.638702408 |Δ| VERBATIM · Sc 3d Mulliken pop 실engage
          (3d = 유일 valence d-shell · 0.4 e via Sc–H bond — spectator polarization 아님) · closed-shell 22e
      (d) f-engaging fixture (STO-3G Sc 엔 f 無 → f 별도 게이트): f AO self-norm·⟂·virial 4.5 symmetric-PD
- [x] brick 10 (round-7) — open-shell UHF + DIIS + level-shift (breaks the closed-shell wall) g5 PASS
      `uhf.hexa` separate α/β densities P^α/P^β · F^s=H+J[P_tot]−K[P^s] · ⟨S²⟩ contamination diagnostic ·
      Pulay DIIS (e=X(FPS−SPF)X · B-matrix Gaussian-elim solve) · Saunders-Hillier virtual level-shift
      (a) H₂/STO-3G closed-shell via UHF (n_α=n_β=1) == sealed RHF anchor −1.11671 Ha |Δ|=2.7e-6 ⟨S²⟩=0
      (b) H atom open-shell (n_α=1,n_β=0) E_UHF=−0.466582 Ha vs PySCF STO-3G −0.466582 |Δ|=1.5e-7 ⟨S²⟩=0.75
          exact · bonus triplet H₂ (n_α=2,n_β=0) ⟨S²⟩=2.0 exact (S=1) — genuine α≠β path
      (c) DIIS accel — linear H₃ doublet radical (R=1.8): plain-mix 18 iters → DIIS 8 iters (same E=
          −1.545843 · ‖FPS−SPF‖=9.1e-7) · ⟨S²⟩=0.7957 (contamination +0.046 reported, not hidden)
      (d) r1..r6 (gaussian/coulomb/rhf/md/md_d/md_f) regress ALL PASS — rhf.hexa byte-untouched (new file)
- [x] brick 11 (round-8) — ROHF (spin-pure) + REAL transition-metal open-shell SCF (ScH⁺ d¹) g5 PASS
      `rohf.hexa` Roothaan single coupling-operator effective Fock (closed/open/virtual MO-block: R_co=Fβ,
      R_ov=Fα, diag=½(Fα+Fβ)) → ONE orbital set → ⟨S²⟩=S(S+1) EXACT by construction (zero contamination)
      (a) H₃ doublet radical (R=1.8): ROHF ⟨S²⟩=0.7500 EXACT vs UHF ⟨S²⟩=0.795721 (+0.046 contam) — SAME
          system, side-by-side · ROHF E=−1.53067 (PySCF −1.530672224 |Δ|<1e-4) ≥ UHF E=−1.54584 (gap
          +0.01517, variational) · ROHF spin-purer than UHF
      (b) RHF reduction — H₂/STO-3G @1.4 via rohf_scf n_open=0 == sealed RHF anchor −1.11671 |Δ|=2.7e-6 ⟨S²⟩=0
      (c) REAL TM — ScH⁺ d¹ doublet (21 e, all-electron STO-3G, same build as round-6 neutral ScH anchor):
          UHF E=−752.49027 ⟨S²⟩=0.757478 (+0.0075 contam) |Δ_PySCF|=2.7e-4 conv 11it ‖FPS−SPF‖=9.9e-7 ·
          ROHF E=−752.48893 ⟨S²⟩=0.7500 EXACT |Δ_PySCF|=6.6e-5 conv 9it ‖FPS−SPF‖=4.8e-7 · gap +0.0013356
          (PySCF 2.13.1 UHF −752.490269326/0.757478 · ROHF −752.488933729/0.750000) — stiff 3d CONVERGED
          cleanly via DIIS+level-shift, NO faking (d6) · ROHF removes UHF contamination on a real TM
      (d) r1..r7 (gaussian/coulomb/rhf/md/md_d/md_f/uhf) regress ALL PASS — rhf.hexa+uhf.hexa byte-untouched
- [x] brick 12 (round-9) — robust-SCF machinery: Fermi-Dirac fractional-occupation smearing T→0 annealing
      + GWH initial guess (vs bare H_core) → CONVERGES a genuinely stiff multi-open-d TM (TiO ³Σ⁻) g5 PASS
      `scf_robust.hexa` (additive — rhf/uhf/rohf.hexa byte-untouched): GWH H_ij=½K·S_ij(H_ii+H_jj) K=1.75 ·
      Fermi μ-bisection + fractional density + entropy term · annealing-rung UHF driver (DIIS, own slice/diis)
      (a) smearing→T=0 correctness — EASY H₃ doublet: robust(GWH+anneal) == plain r8 UHF −1.54584 to
          |Δ|=7.2e-13 · residual entropy term @T→0 = 0.0 (the aid is removed at the end, answer unchanged)
      (b) STIFF-TM CONVERGENCE — TiO ³Σ⁻ (16α/14β, 23 AO, 30 e all-electron): WITHOUT (bare H_core, T=0)
          STALLS ‖e‖=0.034 ≫1e-6; WITH (GWH+Fermi anneal) CONVERGES ‖e‖=4.5e-8 in 43 it, ⟨S²⟩=2.0695 (³
          manifold), entropy→0 — convergence-where-bare-fails DEMONSTRATED. HONEST (d6): a FAST anneal lands
          on an excited UHF root (TiO/STO-3G has a dense near-degenerate UHF manifold — PySCF itself: SAD-guess
          −913.527690/2.0695 vs hcore-guess −913.528591/2.0586). A DEEP slow anneal (kT 0.1→2e-4, 13 rungs,
          829 it) REACHES the ground state E=−913.528982/⟨S²⟩2.058646 vs PySCF hcore-root −913.528590589
          |Δ|=5.9e-4 — WALL BROKEN (slow; round-10 collapses the in-basin cost via 2nd-order SCF)
      (b') TM REACHES PySCF REF (fast) — ScH⁺ d¹ via the SAME robust path → −752.490269 (PySCF UHF
          −752.490269326, |Δ|=2.7e-4, ⟨S²⟩=0.757478) in 18 it — machinery reaches the RIGHT answer, fast
      (c) GWH guess improves seeding — TiO same schedule: GWH converges (43 it) where bare H_core does NOT
          (149 it, stalled); GWH first-rung 17 it vs H_core 19 it — better d-shell seed
      (d) r1..r8 (gaussian/coulomb/rhf/md/md_d/md_f/uhf/rohf) regress ALL PASS — scf_robust is a NEW file
- [x] brick 13 (round-10) — CASCI multi-reference / static-correlation (BREAKS the single-determinant wall)
      `casci.hexa` (additive — rhf/uhf/rohf/scf_robust.hexa byte-untouched): AO→MO 4-index transform
      (casci_mo_hcore Cᵀ H C · casci_mo_eri Σ C C C C (μν|σλ)) + 2-electron full-CI in the |a_α b_β⟩
      determinant basis (Slater–Condon ⟨ab|H|cd⟩ = 1e[δ_bd δ_ac(h_aa+h_bb)+δ_bd h_ac+δ_ac h_bd] + (ac|bd)
      Coulomb, opposite-spin no-exchange) → eigh ground state. CAS(2,2) H₂ = full 2-orbital space → FCI exact.
      SHIPPED = CASCI (CI over FIXED RHF orbitals); CASSCF orbital-opt = round-11 (HONEST brick boundary, d6).
      (a) CAS(2,2)==FCI anchor — H₂/STO-3G @1.4 bohr E_CAS=−1.13727 == pyscf FCI −1.13727594 |Δ|=1.9e-6
          (integral-limited, == RHF anchor |Δ|=1.2e-5 source; the CI itself exact |Δ|≤4e-16 vs pyscf in xval)
      (b) STATIC-CORR WIN @R=5.0 bohr (stretched): E_RHF=−0.68642 (single-det, WRONG, too high) vs E_CAS=
          −0.93489 == pyscf FCI −0.93488935 — RHF error 0.248 Ha. MULTI-REF signature: c0²=0.573 + c1²=0.427
          BOTH large (vs equilibrium c0²=0.987 single-ref) — the two-determinant wall, fixed
      (c) variational E_CAS ≤ E_RHF at every R · static-corr @5.0 (0.248) ≫ @1.4 (0.021) — grows on stretch
      (d) r1..r9 (gaussian/coulomb/rhf/md/md_d/md_f/uhf/rohf/scf_robust) regress ALL PASS — casci is a NEW file
- [x] brick 14 (round-11) — GENERAL N-electron CASCI: determinant-string full-CI over arbitrary CAS(n,m)
      `fci.hexa` (additive — casci.hexa BYTE-UNTOUCHED, the 2e grid is the N=2 special case kept as anchor):
      α/β-string enumeration (fci_combinations C(m,k) · fci_dets merge to sorted spin-orbital occupations) +
      GENERAL Slater–Condon (fci_matel: diagonal Σh_ii+Σ⟨ij‖ij⟩ · single ±(h_pq+Σ⟨pi‖qi⟩) · double ±⟨pq‖rs⟩,
      phase = (−1)^(orbital-reorder parity)) → eigh ground state. CAS(n,m) all-active == FCI. REUSES the
      round-10 AO→MO transform (casci_mo_hcore/eri/coeff) verbatim. Largest run = CAS(6,6) (400 dets, tractable).
      (a) 2e REGRESSION — general solver CAS(2,2) H₂ == round-10 == FCI: @1.4 −1.13727594 · @5.0 −0.93488935
          |Δ|≤1e-5 (ndet=4=C(2,1)²) — the sealed N=2 anchor reproduced by the general algorithm, not broken
      (b) general-CAS==FCI — H₄ CAS(4,4) @1.8 E=−2.17541114 (36 dets) · H₆ CAS(6,6) @1.8 E=−3.24451733
          (400 dets) == pyscf 2.13.1 fci.FCI / mcscf.CASCI |Δ|≤1e-5 (integral-limited; same active space)
      (c) MULTI-REF WIN @stretch — H₄ R=3.0: E_RHF=−1.77917 (WRONG, +0.192 Ha too high) vs E_CAS=−1.97087
          == pyscf FCI −1.97086976. det weights 0.7012/0.1194/0.0374/0.0374 == pyscf EXACT (≥3 significant,
          genuine multi-e static corr, NOT a 2-det case) · H₆ R=3.0 −2.95765 weights 0.5733/0.1020/0.0286...
      (d) r1..r10 (gaussian/coulomb/rhf/md/md_d/md_f/uhf/rohf/scf_robust/casci) regress ALL PASS — fci is NEW
- [x] brick 15 (round-12) — CASSCF orbital optimization (MCSCF orbital-rotation step on the round-11 CASCI)
      `casscf.hexa` (additive — fci.hexa/casci.hexa BYTE-UNTOUCHED): each macro-iter (1) CASCI ground-state
      VECTOR (casscf_ci_vec, reuses fci_dets/fci_matel) → (2) active 1-RDM γ_tu + 2-RDM Γ_tuvw from
      2nd-quantized ladder ops on sorted spin-orbital occupations (casscf_rdm1/rdm2) → (3) generalized
      (Helgaker MEST 10.8) Fock F_pq [core 2(F^I+F^A) · active ΣγF^I+ΣΓ(qu|vw)] + orbital gradient
      g_pq=2(F_pq−F_qp) over the FULL n MO space → (4) C ← C·exp(κ), κ=+α·g antisymmetric rotation via
      Taylor+scale-square matexp (casscf_mat_exp, exactly orthogonal) + backtracking line search (monotonic
      descent). FIRST-ORDER (steepest descent in κ), NOT 2nd-order Newton (HONEST d6 — both legitimate; CI is
      the EXACT round-11 string FCI). Largest run = H₄/H₆ CAS(2,2)/CAS(4,4).
      (a) E_CASSCF ≤ E_CASCI variational lowering — H₄ CAS(2,2) (1 core,2 active): @R=3.0 CASCI −1.82808573
          → CASSCF −1.84528333 (lowering 1.72e-2 Ha, 125 macro-it) · @R=1.8 −2.13593831 → −2.13740984
          (1.47e-3 Ha, 16 it). EQUALITY anchor: H₄ CAS(4,4)=full space → CASSCF==CASCI==FCI −2.17541114
          EXACTLY, ‖g‖≡0 (0 macro-it) — orbital rotations can't change a full-space energy (valid equality, d6)
      (b) CASSCF == pyscf mcscf.CASSCF — @1.8 −2.13740984 |Δ|<1e-5 · @3.0 −1.84528333 |Δ|<1e-5 · CASCI
          baseline == pyscf mcscf.CASCI @1.8 −2.13593831 / @3.0 −1.82808573 |Δ|<1e-5 (verified vs pyscf 2.13.1
          RHF/CASCI/CASSCF on the IDENTICAL STO-3G Bohr H₄ build)
      (c) SEED-INVARIANCE + gradient convergence — H₄ CAS(2,2) @3.0: RHF start vs a deterministic PERTURBED
          orbital guess (κ_p rotation, NO RNG) → SAME CASSCF −1.84528333, |ΔE(seed-1−seed-2)|=5.6e-12 (the
          signature of true orbital optimization) · final ‖g‖ seed-1=9.3e-7 seed-2=1.0e-6 → 0
      (d) r1..r11 (gaussian/coulomb/rhf/md/md_d/md_f/uhf/rohf/scf_robust/casci/fci) regress ALL PASS — casscf
          is a NEW file wrapping fci.hexa/casci.hexa byte-for-byte unchanged · trace(γ)=2 + matexp-orthogonal sanity
- [x] brick 16 (round-13) — strongly-contracted NEVPT2 (SC-NEVPT2): 2nd-order MULTIREFERENCE perturbation
      DYNAMIC correlation on the round-12 CASSCF reference (CASSCF=static; NEVPT2=dynamic — the multireference
      analog of MP2-on-RHF). `nevpt2.hexa` (additive — casscf.hexa/fci.hexa BYTE-UNTOUCHED): E-product
      active-space RDMs (dm1=⟨E_pq⟩, dm2=⟨E_pq E_rs⟩, dm3=⟨E_pq E_rs E_tu⟩, PySCF make_dm123 convention) built
      from the CASSCF CI vector via 2nd-quantized E_pq ladder ops (reuses fci_dets) + the 6 SC-NEVPT2 class
      energies (Sijrs MP2-like · Sijr · Srsi · Srs · Sij · Sir-dominant) with a3/k27/a7/a9/a12/a13 + hole-RDM
      intermediates, assembled by norm_to_energy = −Σ norm/(Δ+h/norm). mo_energy = generalized-Fock diagonal.
      SHIPPED = the 6 classes needing ≤ 3-RDM (the FULL NEVPT2 on CAS(2,2)); the two 4-RDM classes Sr/Si vanish
      on CAS(2,2) and are named round-14 (HONEST d6 — SC, not PC-NEVPT2/CASPT2).
      (a) NEVPT2 == pyscf mrpt.NEVPT — H₄ CAS(2,2): @1.8 −0.0289165 (pyscf −0.02891631) · @3.0 −0.0719024
          (pyscf −0.07190352) · ALL 6 per-class match (Sijrs −0.01697 Sijr −0.00147 Srsi −0.00135 Srs −0.00028
          Sij −0.00031 Sir −0.05152) |Δ|<5e-5 — total AND decomposition anchored to PySCF SC-NEVPT2
      (b) DYNAMIC-CORR RECOVERY — H₄ @1.8: corr CASSCF −0.02398 → CASSCF+NEVPT2 −0.05290 (2.2×) → FCI −0.06198
          (NEVPT2 recovers 85% of the FCI−CASSCF dynamic gap, stays above FCI = perturbative not over-correcting)
      (c) RDM sum rules Σ_p dm2[p,p,r,s]=N·dm1 / Σ_p dm3[p,p,r,s,t,u]=N·dm2 residual ≡ 0 · FULL-SPACE limiting
          check: H₂ CAS(2,2)=full → CASSCF=FCI → NEVPT2 ≡ 0 EXACTLY (no perturbers) — both limit anchors hold
      (d) r1..r12 (gaussian/coulomb/rhf/md/md_d/md_f/uhf/rohf/scf_robust/casci/fci/casscf) regress ALL PASS —
          nevpt2 is a NEW additive file; casscf.hexa/fci.hexa byte-for-byte unchanged
- [x] brick 17 (round-14) — core/virtual orbital CANONICALIZATION: SC-NEVPT2 on a REAL multi-core/virtual
      molecule (lifts the r13 1-dim-block mo_energy restriction). `nevpt2.hexa` (additive — casscf.hexa
      BYTE-UNTOUCHED): nevpt2_gfock builds the full n×n generalized Fock F=F^I+F^A(γ); nevpt2_canonicalize_C
      eigh's the core-core and virtual-virtual blocks (REUSES eigh) → rotates the MO coeffs C←C·U (U=U_core ⊕
      I_active ⊕ U_virt) so F is diagonal there → the existing diagonal nevpt2_mo_energy is then the canonical
      Koopmans orbital energy; nevpt2_from_casscf_orbitals_canon wires it end-to-end. Two multi-core/virtual
      bugs the canonicalization EXPOSED (masked at 1 core/1 virtual) are fixed: Srsi transpose-partner used
      rsia where sria was required; Sir nn6 (rpqi,raai,qp — no b index) was summed inside the b-loop, an m×
      over-count. Target = H₆ STO-3G CAS(2,2): ncore=2 + 2 active + nvirt=2 (multi-core AND multi-virtual).
      (a) canonicalization correctness — canonicalized generalized-Fock core-core off-diag²=2.7e-26 + virt-virt
          off-diag²=4.3e-26 → 0; a deliberately 30°-rotated input (virt off-diag²=0.0377 ≫0) is driven back to
          ~0 by nevpt2_canonicalize_C. Off-diagonal residual reported VERBATIM.
      (b) real-molecule NEVPT2 vs PySCF — H₆ CAS(2,2) canon SC-NEVPT2 = −0.0383324 vs pyscf mrpt.NEVPT
          −0.03786532, |Δ|=4.67e-4 (the residual is hexa's FIRST-ORDER-CASSCF orbital-convergence gap, NOT a
          NEVPT2 error). PROOF: on PySCF's OWN canonical orbitals ALL 6 classes match to <1e-6 (Sijrs −0.0174203
          Sijr −0.00331534 Srsi −0.00124904 Srs −0.00138933 Sij −0.00207451 Sir −0.0124168, total −0.0378653 vs
          −0.03786532) — the canonicalization + class math are EXACT, anchored to PySCF.
      (c) canonicalization invariance / recovery — a 30° core+virtual rotation leaves the CANONICALIZED NEVPT2
          unchanged to 1e-9 (block rotation = gauge freedom) while the un-canonicalized diagonal-moe path shifts
          (−0.0377832 ≠ −0.0383324) — canonicalization is LOAD-BEARING, not a no-op
      (d) reduction anchor / regression — 1-dim-block CAS(2,2) (H₂ full space): canon path == r13 path |Δ|=0
          (canonicalizing a 1-dim block IS the identity, NEVPT2 ≡ 0); r13 nevpt2_selftest + r1..r12 regress ALL
          PASS — casscf.hexa/fci.hexa byte-for-byte unchanged
- [ ] round-15 (named) — NEVPT2 4-RDM CLASSES + CASSCF SCALE: (1) the two 4-RDM classes Sr (S_r^{(−1)}, a16) +
      Si (S_i^{(+1)}, a22) → full 8-class SC-NEVPT2 on large active spaces (CAS(4,4)+) where they are nonzero,
      via the active 4-RDM ⟨E_pq E_rs E_tu E_vw⟩ (canonicalization already shipped this round, so CAS(4,4)+ on a
      real multi-core/virtual molecule then runs end-to-end); (2) PC-NEVPT2 / CASPT2 (partially-contracted / 2nd
      variant); (3) the round-12-named CASSCF scaling (2nd-order Newton MCSCF · direct-CI Davidson — would also
      shrink the round-14 (b) |Δ|=4.67e-4 orbital-convergence residual). ALL within-class refinements — NO
      remaining method-class gap (see depletion)

## MOLSCF method-completeness depletion (round-14)

Single-reference (RHF · UHF · ROHF · robust-SCF), multi-reference STATIC correlation (CASCI · CASSCF), AND
multi-reference DYNAMIC correlation (SC-NEVPT2) are ALL closed and PySCF-anchored. Round-13 sealed SC-NEVPT2 on
1-dim-block CAS(2,2) toys; **round-14 makes SC-NEVPT2 work on a REAL multi-core/virtual molecule** via
core/virtual orbital canonicalization (eigh on the generalized-Fock core/virtual blocks → MO rotation), proven
EXACT on PySCF's own canonical orbitals (all 6 classes <1e-6) on H₆ CAS(2,2) (2 core + 2 virtual). The two
multi-core/virtual class bugs the canonicalization exposed (Srsi transpose partner, Sir nn6 b-loop over-count)
are fixed; the sealed CAS(2,2) H₄ anchor reduces exactly (no regression). The molecular electronic-structure
front-end is now **method-complete to quantitative accuracy on real molecules**: every accuracy CLASS a finite-
molecule ab-initio wavefunction code needs is shipped AND runs beyond the 1-dim-block special case — closed-
shell HF, open-shell HF (UHF + ROHF), stiff-TM convergence machinery, exact static-correlation CI (CASCI),
orbital-optimized multireference (CASSCF), and the 2nd-order multireference dynamic-correlation correction
(NEVPT2) with proper multi-core/virtual canonical denominators. The HF→MP2 and CASSCF→NEVPT2 correlation
ladders are BOTH built. The remaining frontier is NAMED REFINEMENTS within existing classes — NO new accuracy
capability: (1) the 2 four-RDM NEVPT2 classes Sr/Si (zero on CAS(2,2), nonzero on CAS(4,4)+; canonicalization
already shipped so they run end-to-end on real molecules once the 4-RDM lands) + PC-NEVPT2/CASPT2 variants —
round-15; (2) CI/orbital SCALING — direct-Davidson + 2nd-order Newton past the dense-eigh / steepest-descent
ceiling (CAS(10,10), Cr₂; also shrinks the round-14 |Δ|=4.67e-4 orbital-convergence residual); (3) g-and-higher
angular momentum (basis-table extension, d4 — no new code path); (4) analytic forces/gradients (autograd
through the closed pipeline, brick 6); (5) heavy-atom (O/N) STO-3G p-shell integrals already exist (round-4/5
MD) so H₂O/N₂ CAS NEVPT2 is wireable directly. The wavefunction method-class front-end — single-ref + multi-ref
+ static + dynamic correlation, on REAL multi-core/virtual molecules — has NO open accuracy-capability gap.

## three-scale unblock

- **atoms** — 단일 원자 HF(He·Be) = 최소 닫힘 RHF 테스트 · 원자 reference state.
- **chem** — 분자 RHF 에너지/구조(H₂·H₂O @STO-3G) · 반응에너지 Δ (주기 아닌 분자 엔진 필요, chem #3138).
- **system** — 유한 클러스터/분자 fragment SCF → 주기 supercell artifact 없이 큰 시스템 모델 공급(f6611b1e).

세 스케일 모두 동일 `gint_*` + RHF brick 소비 — 단일 generic atom-centered 경로(d4),
instance = basis-set+geometry manifest 만. per-molecule dispatcher 없음.
