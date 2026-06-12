# QFORGE `chem` 스케일 — round-1 설계: NEB → CI-NEB → TS-Hessian(DFPT 재사용)

> 마일스톤 (QFORGE.md §122 chem): **"NEB/TS 반응경로 엔진 (DFPT 선형응답 재사용)"**
> verify = 고-level QM / 실험 배리어. 본 round-1 = lit grounding + 로드맵 + 첫 brick(NEB 메커닉스 정확성).

## 0. 한 줄 요약

화학 반응경로(MEP)·전이상태(TS)를 QFORGE 공통코어 위에서 generic 하게 구한다.
**NEB**(경로) → **CI-NEB**(saddle 정밀화) → **TS-Hessian**(1차조건 검증 + 허수진동수).
TS-Hessian 단계는 새 코드가 아니라 **이미 있는 DFPT 선형응답**(`dfpt.hexa`·`dfpt_response.hexa`·포논 Hessian)을 **그대로 재사용**한다 (d19) — 반응경로 엔진은 포논 엔진의 "Γ-점 Hessian"을 TS 좌표에서 1회 호출하는 thin layer.

## 1. Lit grounding (round-1 · d18 — arxiv + web + NOVEL)

### 1.1 정전 기준(canonical)
- **NEB** — Jónsson, Mills, Jacobsen (1998): image chain + spring force + perpendicular projection. endpoint 고정, 내부 image 만 완화.
- **Improved tangent** — Henkelman & Jónsson, *J. Chem. Phys.* **113**, 9978 (2000): 업윈드(에너지-가중) tangent → kinked-band/corner-cutting 제거. **본 brick 이 구현.**
- **CI-NEB** — Henkelman, Uberuaga, Jónsson, *J. Chem. Phys.* **113**, 9901 (2000): 최고에너지 image 의 평행력 부호반전 → spring 없이 saddle 로 등반. 수렴 시 정확한 1차 saddle. **본 brick 이 구현.**
- **Müller & Brown**, *Theor. Chim. Acta* **53**, 75 (1979): minima 3 + saddle 2 의 곡선 MEP 표준 2D 벤치. 모든 정류점 해석적으로 알려져 success metric 명확. **본 brick 의 verify 레퍼런스.**

### 1.2 단일-끝(single-ended) TS — round-3 후보
- **Dimer method** — Henkelman & Jónsson (1999) + Heyden 외 improved dimer (2005): 두 번째 미분 없이 **최저 Hessian eigenmode** 를 유한차분 회전으로 추정 → 그 모드 방향으로만 에너지 최대화, 나머지 최소화. = minimum-mode following(MMF).
- **Eigenvector following / P-RFO** — 최저 모드 따라 saddle 등반 (Hessian 부분정보).
- 핵심: **dimer/MMF 가 필요로 하는 "최저 Hessian eigenmode" = DFPT 선형응답이 정확히 내놓는 양** → DFPT 재사용 라인이 single-ended TS 까지 자연 확장.

### 1.3 ★ NOVEL probe (arxiv 2026 — 로드맵 직격)
- **arXiv:2601.12630** (v4, 2026-01) — Goswami, Gunde, **Jónsson**, *"Enhanced CI-NEB with Hessian Eigenmode Alignment"*:
  CI-NEB(double-ended) + MMF(single-ended) **adaptive hybrid**. Baker-Chan saddle set + Pt(111) heptamer 59 전이에서 CI-NEB 대비 **에너지·힘 호출 57%(BC)·31%(heptamer) 감소** (Bayesian CrI).
  → **시사**: 우리 로드맵의 "CI-NEB → Hessian eigenmode" 단계가 단순 검증용이 아니라 **수렴 가속 lever** 이다. DFPT 가 Hessian eigenmode 를 (유한차분 dimer 대비) 정확·저비용으로 공급 → 이 hybrid 의 native 적임자.
- **NOVEL 가설(우리 frontier)**: *"DFPT-공급 최저 eigenmode 로 CI-NEB climbing image 의 등반 방향을 매 N-step alignment 하면, 유한차분 dimer 회전 없이 2601.12630 의 가속을 얻는다"* — round-2/3 에서 해석 PES(허수모드 알려진 MB saddle)로 falsify 가능.

## 2. 로드맵 (chem 스케일 brick 체인)

| round | brick | 내용 | verify |
|---|---|---|---|
| **r1 (본 작업)** | `chem/neb.hexa` | NEB 메커닉스: 직선보간 + improved tangent + spring + perp-projection + CI climbing. d4-generic PES 콜백. | 해석 PES (1D 이중우물·MB 2D) saddle/배리어 vs 해석 레퍼런스. **g5 PASS.** |
| r2 | `chem/neb.hexa` 확장 | 실 분자 PES 어댑터: QFORGE SCF force 를 `pes_grad` dispatcher 케이스로 연결 (d4 — 엔진 미접촉). H+H₂ / SN2 등 소계 배리어. | 고-level QM 배리어 vs 문헌. |
| r3 | `chem/ts_hessian.hexa` | **DFPT 재사용**: CI-NEB saddle 좌표에서 `dfpt_response`/포논 Hessian 1회 호출 → 고유치 1개 음수(허수진동수) 확인 = TS 1차조건. ZPE/허수ν 리포트. | 정확히 1개 허수모드 (Müller-Brown saddle Hessian 해석값 대조). |
| r4 | `chem/dimer.hexa` (single-ended) + hybrid | dimer/MMF + **DFPT eigenmode alignment**(2601.12630 NOVEL). climbing 방향을 DFPT 최저모드로 정렬. | CI-NEB 대비 force-call 감소 + 동일 saddle. |
| r5 | rate const | Eyring/하모닉 TST: k = (k_BT/h)·exp(−ΔG‡/k_BT), ΔG‡ 는 r3 ZPE+허수모드에서. | 실험 Arrhenius. |

## 3. 공통코어 재사용 매핑 (d19 — NEXUS edge)

| chem 단계 | 재사용 대상 | provides → reuses 엣지 |
|---|---|---|
| `pes_grad` (r2+) | `stdlib/qforge/` SCF force (Hellmann-Feynman) | qforge.scf → chem.neb |
| TS-Hessian (r3) | `dfpt.hexa` · `dfpt_response.hexa` · 포논 dynamical matrix | qforge.dfpt → chem.ts_hessian |
| eigenmode (r3/r4) | DFPT 선형응답 최저 고유벡터 + `eigen` | qforge.dfpt → chem.dimer |
| optimizer | autograd.hexa force-step (MD chain 동형) | qforge.autograd → chem.neb |

→ **반응경로 엔진은 신규 물리 엔진이 아니라 포논/DFPT 엔진의 thin orchestration layer.** TS Hessian = Γ-점 dynamical matrix 를 (주기 결정 대신) 분자 TS 좌표에서 1회 평가.

## 4. d4-generic 설계 (이름분기 0)

엔진(`neb_relax`)은 PES 를 **`pes_id` 정수 selector** 로만 본다. `pes_energy`/`pes_grad` dispatcher 가 manifest:
```
0 = 1D 대칭 이중우물  V=(x²-1)²
1 = Müller-Brown 2D
(r2) 2 = QFORGE SCF force ...   ← 케이스 한 줄 추가, 엔진 미접촉
```
새 PES/분자 추가 = dispatcher 한 줄. 엔진·tangent·spring·climbing 로직 전부 차원-generic(D-차원 flat 벡터).

## 5. round-1 정직 범위 (d6)

- ✅ 구현·검증: NEB/CI-NEB **메커닉스 정확성** — improved tangent, spring, perp-projection, climbing image 가 해석 PES 에서 알려진 saddle/배리어로 수렴.
- ❌ 아직 아님: 실 분자 SCF PES(r2), DFPT Hessian 결합(r3), rate const(r5). 전체 화학반응 엔진이 **아니다**.
- verify 레퍼런스는 **해석 PES**(MB saddle/배리어 정확값) — 실험 배리어 대조는 r2+.

## 6. round-2 next-list

1. `pes_grad` 케이스에 QFORGE SCF force 연결 (d4 dispatcher 한 줄) — H+H₂ 콜리니어 배리어(≈9.7 kcal/mol 문헌) 첫 실분자 verify.
2. NOVEL falsify: DFPT 최저모드 alignment 가속 가설 — MB saddle 의 해석 Hessian 허수모드를 ground-truth 로, alignment-CI-NEB 의 force-call 수를 plain CI-NEB 대비 측정.
3. `chem/ts_hessian.hexa` 스텁: MB saddle 에서 해석 Hessian 고유치 부호(1 음수) → TS 1차조건 g5.
