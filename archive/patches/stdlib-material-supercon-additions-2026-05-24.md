---
slug: stdlib-material-supercon-additions-2026-05-24
status: partial
---

> **Status (2026-05-25): top-3 모두 처리.** #1 `allen_dynes_full` = 이미 구현됨 (`stdlib/material/sim.hexa` + `verify_cli.hexa` 미러). #18 canonical home = **`stdlib/material/sim.hexa`** 가 사실상의 home (verify_cli 가 "mirrors sim.hexa verbatim"; true import-DRY 는 verify_cli multi-module link 취약성 때문에 별도 follow-up). #4 `eliashberg_moments_from_a2f` = **CLOSED** — sim.hexa 0.3.0 에 α²F → [λ, ω_log, ω̄₂] 트라페조이드 적분 추가 (`sim_test.hexa` 해석해 anchor 8/8 PASS · diff-guard CLEAN). 잔여 = 후보 24건 (B EOS·구조 / C 등) — 필요 시 개별 slug.

# stdlib/material 추가 후보 27선 — RTSC 캠페인 depletion 브레인스토밍

**Reporter**: claude (`dancinlab/demiurge` · RTSC V1–V4 verify + h3cl EOS 세션 · 2026-05-24)
**Severity**: medium (기능 부재 아님 — 반복 ad-hoc 계산을 stdlib로 승격 + verify_cli 🔵/🟢 escalation 전제)
**Scope**: `stdlib/material/` (+ `tool/verify_cli.hexa` recompute 카탈로그 · atlas)
**Siblings**: [[verify-cli-supercon-fns-2026-05-24]] (PR #745로 6 fn 등록 — 본 건은 그 후속 확장)

## TL;DR

RTSC 캠페인(supercon DFT·Allen-Dynes·Eliashberg·EOS·BEE-NET/ALIGNN 교차검증)에서 **실제로 손으로 때운 계산**을 고갈-브레인스토밍으로 27건 도출. 이미 있는 9종(`allen_dynes_tc` `mcmillan_tc` `bcs_weak_tc`/`bcs_gap_ratio` `whh_hc2_zero` `migdal_ratio` `lambda_eliashberg` `beenet_grid_bins` `inverse_variance_consensus`/`sigma_from_spread`)은 제외.

**top-3 (ROI 최고)**:
1. **#18 `stdlib/material/supercon.hexa` 단일 canonical home** — `verify_cli.hexa`가 `_allen_dynes_tc` 사본을 따로 들고 있음(d3 위반 냄새). 한 파일로 통합 → verify_cli가 import → 신규 fn 추가 시 1곳만.
2. **#1 `allen_dynes_full`** (f1 강결합 + f2 shape 보정) — 현 기본 AD는 λ>1.5에서 과소평가. CaH₆ λ=4.4·h3o λ=2.7 같은 강결합 hydride에서 부정확.
3. **#4 `eliashberg_moments_from_a2f`** — V1 §E5가 지목한 🟢→🔵 escalation 전제 (α²F(ω)→λ·ω_log·ω̄₂).

## 후보 27선 (quadrant별)

### A. supercon closed-form 완성 (기존 AD/BCS 보강)
| # | fn | 시그니처(안) | RTSC 근거 |
|---|---|---|---|
| 1 | `allen_dynes_full` | (λ, ω_log, ω̄₂, μ*) → Tc | f1=[1+(λ/Λ1)^1.5]^⅓, f2 보정. 기본 AD가 λ>1.5 과소 (CaH₆/h3o) |
| 5 | `morel_anderson_mustar` | (μ, E_F, ω_ph) → μ* | μ*=0.10/0.13을 입력 상수로만 사용 — 유도 부재 |
| 7 | `bcs_gap_temperature` | (T, Tc) → Δ(T)/Δ(0) | bcs_gap_ratio(0-arg)만 있음 |
| 11 | `eliashberg_gap_solve` | (α²F, μ*, T) → Δ, 2Δ/kTc | 강결합 2Δ/kTc (H₃S 4.8 vs BCS 3.528) |
| 17 | `mcmillan_hopfield_eta` | (N_EF, ⟨I²⟩, M, ⟨ω²⟩) → η, λ | λ를 전자/포논 기여로 분해 |
| 24 | `eliashberg_2band` | (λ_ij, ω, μ*) → Tc | MgB₂급 2-gap (speculative) |

### B. EOS · 구조 · 압력
| # | fn | 근거 |
|---|---|---|
| 2 | `birch_murnaghan_fit` + `bm_pressure`/`bm_modulus` | h3cl EOS를 손으로 (B~670 finite-diff). (V,E)→B0,B0',V0 |
| 16 | `grid_convergence_extrapolate` | RTSC λ ladder 16³→6³q under-conv 진단 (1/N Richardson) |
| 26 | `weighted_bz_average` | parse_elph_gen.py가 q-weight [4,12,12,…] 손으로 가중 |
| 27 | `per_atom_normalize` / `per_formula_unit` | celldm 간 E 비교 수동 정규화 |

### C. 파서 / ingest
| # | fn | 근거 |
|---|---|---|
| 4 | `eliashberg_moments_from_a2f` | V1 §E5 escalation 전제. α²F→λ·ω_log·ω̄₂ |
| 9 | `qe_scf_parse` / `qe_ph_parse` | eos.sh·parse_elph_gen.py ad-hoc grep/awk (E·P·E_F·λ·ω_log) |

### D. units / 변환
| # | fn | 근거 |
|---|---|---|
| 3 | `units` 모듈 (ry_to_ev·bohr_to_ang·kbar_to_gpa·kelvin_to_mev·cm1_to_mev) | kbar/10→GPa, a³/2→V 수동 변환 |
| 14 | `theta_d_omega_log_convert` / `debye_from_elastic` | mcmillan_tc Θ_D 입력 — 변환 부재 |
| 20 | `ry_per_bohr3_to_gpa` (=14710.5) | 원시 stress tensor 파싱 시 (hyper-narrow) |

### E. 안정성 / 포논
| # | fn | 근거 |
|---|---|---|
| 8 | `dynamical_stability_flag` (ω_min<0→unstable) | h3o/h3f/h3si imaginary mode 수동 판정 |
| 23 | `lindemann_ratio` | imaginary-mode cheap screen (full SSCHA 전) |
| 25 | `anharmonic_renorm_estimate` (poor-man SSCHA) | h3o imaginary mode — GPU SSCHA 전 cheap 예측 |

### F. ML 교차검증 / 통계
| # | fn | 근거 |
|---|---|---|
| 12 | `rel_err` / `mae` / `ensemble_mean_std` | BETE-NET/ALIGNN 91–98% under-pred 수동 계산 (D1·D3·D5) |
| 13 | `power_law_fit` (Tc∝m^−p) | group-16 1/√m ladder (V1 §B8) |
| 21 | `tc_uncertainty_band` (∂AD 전파) | Tc를 broadening-range로 보고 중 — 원리적 band |

### G. 파생량 (superconductor)
| # | fn | 근거 |
|---|---|---|
| 15 | `coherence_length`·`penetration_depth`·`hc_thermo` | §8 device-side가 whh(Hc2)만 — ξ·λ_L·Hc 누락 |

### H. 열역학 / 안정성
| # | fn | 근거 |
|---|---|---|
| 10 | `formation_enthalpy` + `convex_hull_distance` | **M9 미해결** metastability/quench (분해 엔탈피 Cl+3/2 H₂) |

### I. meta / contrarian
| # | fn | 근거 |
|---|---|---|
| 18 | **`stdlib/material/supercon.hexa` canonical home** | d3: verify_cli `_allen_dynes_tc` 사본 중복 제거 |
| 19 | `physicality_guard` (λ<0·μ*>λ·Tc虛 사전 차단) | ALIGNN 음수 λ(h3o −0.42)·CaH₆ NaN spam — 침묵 NaN→타입 에러 |
| 22 | atlas: BCS 3.528=π·e^(−γ) 🔵 0-arg 상수 등록 | chsh_tsirelson 패턴 (pure-formal atom) |

## 권장 진입 순서

1. **#18 canonical home** 먼저 (d3 해소 + 이후 fn의 단일 착지점) → `stdlib/material/supercon.hexa`, verify_cli가 import.
2. **#1·#4·#5** (closed-form 3종, 모두 verify_cli `--expr` + atlas register 가능 → 즉시 🔵/🟢).
3. **#2·#3** (EOS fit + units — 반복 ad-hoc 제거 ROI 큼).
4. 나머지는 RTSC 후속(SSCHA·convex-hull·2-band) 진행 시 pull.

## hexa atlas 업데이트 사안 (검토 결과)

**핵심: supercon 6 fn atlas 흡수는 이미 완료** — PR #745 (`f14790bc` "atlas(F): register 6 supercon verified-* nodes — RTSC V2 🟢 closure")가 `embedded.gen.hexa`(binary-builtin atlas SSOT)에 6개 @F 노드를 등록함:

| 이미 등록된 node | witness |
|---|---|
| `verified-allen_dynes_tc-num` | allen_dynes_tc(2.5,1100.0,0.1)=149.923 |
| `verified-mcmillan_tc-num` | mcmillan_tc(2.5,1100.0,0.1)=149.923 |
| `verified-bcs_gap_ratio-num` | bcs_gap_ratio()=3.52775 |
| `verified-migdal_ratio-num` | migdal_ratio(25.0,10000.0)=0.0025 |
| `verified-lambda_eliashberg-num` | lambda_eliashberg(0.5)=1.0 |
| `verified-beenet_grid_bins-num` | beenet_grid_bins(140.0,1.0)=141.0 |

⚠ **실제 미결 사안 = atlas binary rebuild**. `hexa atlas lookup --prefix=allen_dynes`/`bcs` 가 "no nodes match"를 주는 이유는 미등록이 아니라 **loaded `atlas.n6`가 #745 이후 rebuild 안 됨** (source에는 6 노드 있으나 binary는 16082 stale). → atlas.n6 regenerate 시 6 노드 로드 (16082→16088). 본 세션 register 재시도는 **중복**이라 revert함.

### atlas 관련 신규 gap (inbox-worthy)
1. **atlas rebuild 트리거 부재/불명확** — register가 embedded.gen.hexa에 fold하지만 loaded binary 갱신은 별도. #745 노드가 여태 안 로드됨이 증거. rebuild를 register/install 사이클에 묶거나 `hexa atlas rebuild` verb 필요.
2. **`atlas register --from-verify` 3-op 미지원** — 현재 1-op(`<fn> <n> <v>`)·2-op(`<a> <b> <v>`)만. allen_dynes_tc/mcmillan_tc는 3-op(λ·ω·μ)인데 register는 못 받음(verify --expr는 4-op까지 받는데 register는 2-op 천장). #1 `allen_dynes_full`(4-op) 등록하려면 register arity 확장 필요.
3. **register dedup 부재** — 같은 id(`verified-migdal_ratio-num`)를 다른 witness로 append 시 중복 노드 생성(본 세션 실측). id 충돌 시 replace/skip 필요.

### 후속 흡수 (구현 후)
- 브레인스토밍 #1 `allen_dynes_full`·#5 `morel_anderson_mustar` 등 신규 closed-form → 구현 + verify_cli 등록 후 register (단 3-op는 gap #2 선결).
- **bcs_gap_ratio 🔵 격상** — 현 libm 평가라 🟢. 2π/e^γ를 symbolic C-constant로 등록 시 🔵 (chsh_tsirelson=2√2 패턴).
- **측정 anchor** (H₃S 203K · CaH₆ 215K) — E(experiment) 노드 후보, 별도 citation 경로.

## 고갈 메타
- 6 quadrant · 27 후보 · 6 라운드 (round 6에서 신규의 >50% 패러프레이즈 → 고갈)
- unfilled: 측정-ingest 파서(Tier-3, 외부 데이터 의존 → adapter 영역) · 2-band(speculative)
- 출처: demiurge RTSC `RTSC/verify/V1–V4` + `exports/material_discovery/rtsc_h3cl_eos_im3m_20260524.json`
