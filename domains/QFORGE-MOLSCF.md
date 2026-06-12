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
- [ ] brick 13 (round-10) — 2nd-order/Newton-SCF (collapse the deep-anneal in-basin cost) + multi-reference
      frontier (Cr₂ → CASSCF, beyond single-determinant) + g 각운동량 (15 Cart → 9 spherical) + brick 6 force

## three-scale unblock

- **atoms** — 단일 원자 HF(He·Be) = 최소 닫힘 RHF 테스트 · 원자 reference state.
- **chem** — 분자 RHF 에너지/구조(H₂·H₂O @STO-3G) · 반응에너지 Δ (주기 아닌 분자 엔진 필요, chem #3138).
- **system** — 유한 클러스터/분자 fragment SCF → 주기 supercell artifact 없이 큰 시스템 모델 공급(f6611b1e).

세 스케일 모두 동일 `gint_*` + RHF brick 소비 — 단일 generic atom-centered 경로(d4),
instance = basis-set+geometry manifest 만. per-molecule dispatcher 없음.
