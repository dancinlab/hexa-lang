# A3 — DEMIURGE axis: 반물질 공장 7공정 논문 흡수 → ANTIMATTER cross-link

> ARXIV 도메인 A3 마일스톤. DEMIURGE axis (physics.atom-ph · physics.acc-ph · hep-ex) 본격 흡수.
> A1(ingest POC 12편) + A2(ANIMA 11편)에 이어 **A3 는 반물질 공장(antihydrogen factory)의
> 7공정(생성→감속→포획→냉각→합성→가둠→측정) 물리 논문** 12편을 흡수한다.
> **A3 는 ARXIV 첫 축으로서 verify-able recompute 를 실제로 닫는다** — DEMIURGE 가 verify-native
> 도메인이라 RFC-045-style 물리 fn 이 이미 `hexa verify --expr` 에 깔려 있기 때문 (A1·A2 = 0).

## 1 · 한 문단 요약

arXiv API 6 query → **12편 on-topic 흡수** → 3-class triage:
**verify-able 5종 LIVE** (per-paper 가 아니라 논문들이 **인용하는** 공유 ANTIMATTER fn — A2 와의 핵심 차이) ·
**🟡 citation 7** (atlas reference node) ·
**handoff→demiurge 12** (12편 전부 ANTIMATTER 7공정에 명시 cross-link).
A3 의 산출 가치 = **citation + demiurge cross-pollination(7공정 map) + 논문이 인용하는
threshold/cooling-scaling 상수의 DIRECT verify 확인**.
A2(ANIMA: 0 verify-able — in-tree IIT primitive 부재)와 달리 **A3 는 5종 물리상수를 지금 닫는다**.

## 2 · 핵심 A3 발견 — DEMIURGE 는 verify-native (A2 대비)

HEAD 드라이버(#1153) · mini arm64 · `POOL_DISABLE=1` 에서 **LIVE 확인**:

| fn (정수-exact) | verify | 공정 | 물리 의미 |
|---|---|:---:|---|
| `pair_threshold_kinetic_factor 1 6` | 🔵 SUPPORTED-FORMAL | ⓵생성 | 반양성자 쌍생성 운동에너지 임계 T_th=6·m_p_c² |
| `pair_threshold_total_factor 1 7` | 🔵 SUPPORTED-FORMAL | ⓵생성 | 빔 전체에너지 임계 E_beam,th=7·m_p_c² |
| `cyclotron_cool_massexponent 1 3` | 🔵 SUPPORTED-FORMAL | ⓸냉각 | 사이클로트론 냉각 τ_c∝m³ (질량 지수) |
| `cyclotron_cool_bratio_exponent 1 2` | 🔵 SUPPORTED-FORMAL | ⓸냉각 | 냉각비 τ_c∝B⁻² (자기장 지수) |
| `cyclotron_cool_bexponent 0 -2` | 🔵 SUPPORTED-FORMAL | ⓸냉각 | 싱크로트론 냉각 B-지수 (−2 exact) |
| `pair_threshold_kinetic_factor 1 5` | 🔴 FALSIFIED (calc=6≠5) | — | 결정성 음성 대조군 (determinism control) |

→ **5종 정수-exact ANTIMATTER 물리상수가 지금 🔵 verify-able**. 12편 중 6편이 이 상수 중
하나를 인용하는 claim 보유 → 해당 claim facet 은 (b)→(a) 로 re-tier (🔵).
float-path Penning 3주파(`penning_omega_plus/minus` 2-arg) + `h1s2s_rydberg` 2-arg 는
소스+atlas 에 존재하나(`penning_invariance` @F 는 2026-05-25 fold 완료, 🟢) **설치된 드라이버의
`_recompute_float` 에 2-arg dispatch 가 없어** float form 은 🟠 NO-PATH → V9 float-driver 재빌드 시 🟢.

## 3 · 흡수 논문 12편 (process map)

기호: 🔵 폐형해/verify-confirmed · (b) citation · (c) handoff · (*) verify-able-CANDIDATE

| arxiv id | 제목 (저자) | 기여 | class | demiurge 공정 |
|---|---|---|---|---|
| 0805.4082 | Particle Physics Aspects of Antihydrogen w/ ALPHA (ALPHA 2008) | 포획된 H̄ 1S-2S 가 CPT 검증·Planck-scale 탐침 | (b) | ⓻측정 (CPT 동기) |
| 1201.3944 | H̄ / mirror-trapped p̄ discrimination (Amole+ 2012) | minimum-B(octupole+mirror) 트랩, 소멸위치로 H̄ vs p̄ 구분 | (c)*·(b) | ⓺가둠 (minimum-B) · ⓻측정 |
| 1909.07493 | Antiproton Deceleration Device for GBAR (Husson+ 2019) | 정전기 감속 → 수 keV p̄, degrader-foil 손실 회피 | (c) | ⓶감속 (정전기 감속) |
| 1606.06697 | Beam Dynamics / Low Energy Antiproton (Resta-Lopez+ 2016) | ELENA/USR 100→20 keV, space-charge·scattering 한계, AD 대비 10-100× | (c) | ⓶감속 (ELENA ladder) |
| 1507.04147 | A reservoir trap for antiprotons (Smorra+/BASE 2015) | p̄ 분량 추출 → Penning 트랩, >1.08년 저장, 가속기-독립 | (c)*·(b) | ⓷포획 (reservoir 저장) |
| 2409.04509 | Quasi-analytical 1S-2S lineshape (Azevedo+ 2024) | AC-Stark+ionization 해석적 lineshape → 1S-2S 중심주파 fit | (c)*·(b) | ⓻측정 (1S-2S 중심주파) |
| 2002.09348 | Testing Fundamental Physics in H̄ (Charlton+ 2020) | 1S/2S/2P 주파+free-fall 로 Lorentz/CPT/EEP/WEP bound | (c)*·(b) | ⓻측정 (CPT/EEP bound) |
| 1409.0705 | Free fall & grav quantum states of antimatter (Dufour+/GBAR 2014) | GBAR 극저온 H̄ free-fall, quantum reflection, 중력 양자상태 | (c) | ⓻측정 (free-fall ḡ) · ⓹합성 |
| 1905.03281 | H̄ level population: positron plasma length (Radics+ 2019) | 3체 재결합 지배, ground-state yield 가 plasma length power-law | (c)* | ⓹합성 (재결합 level-pop power-law) |
| 0307151 | Positron plasma diagnostics & T control (ATHENA 2003) | plasma-mode 비파괴 T/n 제어, H̄ yield 가 밀도·T 의존 | (c) | ⓸냉각 (양전자 plasma T) · ⓹합성 |
| 1401.1939 | Towards high-precision p̄ magnetic moment (Smorra+/BASE 2014) | BASE double-Penning p̄ 자기모멘트 → 엄격 baryon CPT | (c)*·(b) | ⓷포획 (double Penning) · ⓻측정 (g-factor) |
| 1907.01460 | Grav effects on geonium / electron g_s in Penning (Ulbricht+ 2019) | **Brown-Gabrielse g_s formula(Rev.Mod.Phys.58,233) 를 중력 포함 확장** | (c)*·(b) | ⓷포획 (Brown-Gabrielse 불변량 origin) |

`(*)` = verify-able-CANDIDATE — A3 에서는 threshold(⓵)·cooling-scaling(⓸) 정수상수는 **지금 닫힘(a)**,
Penning 3주파 float form + 1S-2S Rydberg 주파는 **V9 float-driver 재빌드 시 🟢** (deferred).

## 4 · ANTIMATTER 7공정 cross-link 매핑 (12 handoff)

demiurge `~/core/demiurge/ANTIMATTER.md` 의 7공정 spine 에 논문 매핑:

| 공정 | 흡수 논문 → 기여 | verify 상태 |
|---|---|---|
| **⓵생성** generate | (공통) pair-production threshold T_th=6·m_p_c² · E_beam=7·m_p_c² | **🔵 VERIFY-CONFIRMED** (`pair_threshold_kinetic/total_factor`) |
| **⓶감속** decelerate | 1909.07493 GBAR 정전기 감속(수 keV) · 1606.06697 ELENA/USR 빔동역학(100→20 keV) | handoff (V9 빔동역학 수치 후보) |
| **⓷포획** capture | 1507.04147 reservoir Penning(>1년) · 1401.1939 BASE double-Penning · 1907.01460 Brown-Gabrielse g_s | `penning_invariance` @F 🟢 (불변량) + float 3주파 V9 candidate |
| **⓸냉각** cool | 0307151 ATHENA 양전자-plasma T 제어 | **🔵 VERIFY-CONFIRMED** cooling scaling (`cyclotron_cool_*`, τ_c∝m³·B⁻²) |
| **⓹합성** synthesize | 1905.03281 3체 재결합 level-pop power-law · 1409.0705 GBAR 극저온 H̄ | handoff (V9 재결합률 폐형해 후보) |
| **⓺가둠** confine | 1201.3944 minimum-B(octupole+mirror) 트랩 구분 | RTSC 자석 toolchain(getdp 4.0 · Ioffe-Pritchard) 상속 |
| **⓻측정** measure | 0805.4082 CPT 동기 · 2409.04509 1S-2S lineshape · 2002.09348 CPT/EEP/WEP bound · 1409.0705 free-fall · 1401.1939 g-factor CPT | 1S-2S 2.4661 PHz = `h1s2s_rydberg` (V9 float candidate) |

**⓺가둠 = RTSC 직계 상속**: ANTIMATTER.md §4 에 따라 ⓺가둠은 RTSC 자석 cell(`solenoid_axisym.geo/.pro`,
Wheeler 폐형해)을 Ioffe-Pritchard 자기최소 트랩으로 파생 — 1201.3944 의 octupole+mirror minimum-B 트랩이
바로 그 device. 같은 getdp magnetostatic 척추, 형상만 다름.

## 5 · V9 physics-primitive seed (다음 🟢 타겟)

A3 가 지금 닫은 것 = 정수-exact threshold/cooling-scaling. **다음 verify-able-CANDIDATE**:

1. **Penning 3주파 float form** — `penning_omega_plus/minus(ω_c,ω_z)` 2-arg float dispatch.
   소스(tool/verify_cli.hexa)+atlas(`penning_invariance` @F 🟢 fold 2026-05-25)에 이미 존재,
   **설치 드라이버 `_recompute_float` 의 2-arg wire 만 없음** → V9 float-driver 재빌드 시 즉시 🟢.
   (1507.04147 / 1401.1939 / 1907.01460 의 Brown-Gabrielse 불변량 cross-check)
2. **1S-2S Rydberg 주파** — `h1s2s_rydberg(R∞,c)` = (3/4)·R∞·c ≈ 2.4661 PHz (2-arg float).
   (2409.04509 lineshape / 0805.4082·2002.09348 CPT 측정의 중심주파)
3. **3체 재결합률 scaling** — 1905.03281 / 1409.0705 power-law → demiurge ⓹합성 폐형해 recompute 후보.

## 6 · 거버넌스 · 정직성

- verify 정본 = `hexa verify` g5 — A3 는 triage + LIVE 5종 verify 확인. LLM 자기판정 금지.
- A3 verify-able = **honest 5종 🔵** (A1·A2 와 달리 DEMIURGE 가 verify-native).
  나머지(Penning float·Rydberg·재결합률)는 정직하게 V9 float-driver/physics primitive 로 deferred.
- naive dump 금지 — 12편 전부 ANTIMATTER 7공정 명시 cross-link 보유 → 흡수 인정.
- arXiv = open-access. attribution = arxiv id + 저자 + 제목.
- query 2(generic CERN accel)·ELENA-tunnelling SW(2510.00289 이름충돌)·CPT 이론 동기 다수는
  off-topic/subsumed 로 DROP (verdict 참조).
- **demiurge handoff 주의**: demiurge working tree 가 dirty feature 브랜치
  (`feat/rtsc-magnet-wheeler-v2`, untracked hexa-fusion-7gate PDF) 위 → A2 anima 패턴 +
  memory `feedback_closure` 에 따라 A3 는 핸드오프를 working-copy edit 로 **append (stub-first, dedup)**
  하되 **공유 dirty demiurge 트리에서 commit 하지 않음**. demiurge 세션이 commit 必 (parent 보고).

## 7 · 다음 (A4 readiness)

A3 = DEMIURGE axis CLOSED (citation + handoff + **첫 verify-able recompute 5종 🔵**).
다음 = **A4 PHANES axis** (autonomous-discovery / OUROBOROS 논문 → loop 알고리즘, handoff to `~/core/phanes`).
DEMIURGE verify-able 추가분(Penning float·1S-2S Rydberg·재결합률)은 V9 physics-primitive lane 랜딩 후 재방문.
