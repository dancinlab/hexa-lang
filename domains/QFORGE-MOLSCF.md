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
- [ ] brick 7 — p/d 각운동량 (Hermite recursion · 실제 화학 분자)

## three-scale unblock

- **atoms** — 단일 원자 HF(He·Be) = 최소 닫힘 RHF 테스트 · 원자 reference state.
- **chem** — 분자 RHF 에너지/구조(H₂·H₂O @STO-3G) · 반응에너지 Δ (주기 아닌 분자 엔진 필요, chem #3138).
- **system** — 유한 클러스터/분자 fragment SCF → 주기 supercell artifact 없이 큰 시스템 모델 공급(f6611b1e).

세 스케일 모두 동일 `gint_*` + RHF brick 소비 — 단일 generic atom-centered 경로(d4),
instance = basis-set+geometry manifest 만. per-molecule dispatcher 없음.
