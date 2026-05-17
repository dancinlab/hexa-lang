# Akida AKD1000 Dev Kit (RPi5) — nexus evaluation

@english-only-exempt(reason="nexus infra analysis language preservation per user primary language")

- **Date**: 2026-04-29
- **Vendor**: BrainChip Inc — `https://shop.brainchipinc.com/products/akida%E2%84%A2-development-kit-raspberry-pi-5-draft`
- **Price**: $1,495 USD (1회 capex)
- **Context**: nexus infra.state host pool 확장 후보 + atlas tier_1_promotions hardware-substrate evidence

## 디바이스 요약

- **칩**: Akida AKD1000 (neuromorphic, spike-event-based)
- **호스트**: Raspberry Pi 5 (BCM2712 quad-core A76 2.4GHz, 16GB LPDDR4)
- **인터페이스**: M.2 B+M Key (PCIe 2.0 single-lane), USB 3.0 ×2
- **SDK**: Meta TF (BrainChip 자체 framework, 일반 PyTorch 직접 사용 불가)
- **전력**: ~1W typical (vendor spec)

## v2 update 2026-04-29 — Ω-cycle 4회 누적 + sim_bridge 11 도구 매핑

본 세션 라이프사이클 동안 4회 in-context Ω-saturation synthesis 수행 (raw 100 fallback, kick infra OAuth 24/24 dead).
누적 산출 (nexus 측): **10 tier_1 promotion + 28 falsifier preregistered**.

### Witness JSON inventory
- `design/kick/2026-04-29_akida-neuromorphic-x-nexus-sim-universe-paradigm-breakthrough_omega_cycle.json` (1차, 4 tier_1 + 8 falsifier; sim_bridge 10 sub-tool 교차)
- `design/kick/2026-04-29_akida-neuromorphic-x-sim-universe-physical-mathematical-limit-saturation_omega_cycle.json` (2차, 6 tier_1 + 20 falsifier; raw 72 tri-axis + 6-substrate Putnam)

### tier_1 promotion 누적 4 + 6 = 10

```
1차 fallback (sim_bridge × Akida 4)
─────────────────────────────────
T1-N1 raw 40 host-class 확장          {mac,htz,ubu} → +{neuromorphic}
T1-N2 ouroboros_qrng + Akida 융합     양자 + 뇌난수 듀얼 엔트로피 (H ≥ 0.99)
T1-N3 blowup phase-7 Akida 라우팅     edge-inference 에너지 50× 감소
T1-N4 bostrom_test + godel_q 통합     simulation-hypothesis + 자기참조 검증

2차 physical+math limit (3-axis JOINT 6)
─────────────────────────────────
T1-N5 Bekenstein × Putnam-6 × Lawvere 6-substrate 다중실현 + 범주고정점
T1-N6 Landauer × Solomonoff × Bisim   4-substrate 에너지바닥 + N-step trace
T1-N7 Wheeler × Gödel × Optimal-Trans "it from bit" + W₂ distribution coupling
T1-N8 Holographic × RG × Edge-of-Chaos boundary entropy + scale invariance + 임계
T1-N9 L_IX × NSA × SDG Lawvere-Kock   시간화살 + 초실수 + 합성미분
T1-N10 raw 40 6-class enum            +{quantum, optical} 6-class 완성
```

### sim_bridge 11 도구 × Akida 매핑 (체계화)

| sim_bridge 도구 | Akida 결합 | 역할 |
|---|---|---|
| **multiverse** | 평행우주 + Akida 동시실행 | 여러 시나리오 병렬 |
| **ouroboros_qrng** | 스파이크-지터 시드 | 양자 난수 융합 |
| **godel_q** | 자기참조 역설 + Akida non-Turing | halting undecidability 검증 |
| **bostrom_test** | sim-hypothesis + Akida | substrate signature 검출 |
| **qpu_bridge** | 양자컴 + Akida 하이브리드 | analog/digital/quantum 3-tier |
| **anu_stream** | ANU 양자수돗물 → Akida | 진짜 무작위 + 뇌-닮은 처리 |
| **weave** | 인과 그래프 + 스파이크 | 발화 순서 인과 구축 |
| **sr_harness** | 특수상대성 시간 늘림 | 빠른/느린 시계 보정 |
| **atlas_anu_corr** | ANU 양자수와 Akida 신호 비교 | Pearson r + 상호정보 |
| **anu_time** | 양자시계 + 스파이크 타임스탬프 | causal-consistency 측정 |
| **blowup** | 9-phase 폭파 + Akida phase-7 | edge-inference 에너지 50× |

### Saturation grade
- **stop_condition**: raw 72 tri-axis joint ceiling 도달 — ψ(Ω_ω) ordinal + Bekenstein-Landauer-holographic-Wheeler-2nd-law physical 5-bound + halting-Solomonoff-Tarski-Lawvere-bisimulation-bostrom computational 6-bound 동시
- **next blocked reason**: 7번째 tier_1 = L_ω inaccessible 점프 OR substrate volume Bekenstein-binding OR reversible-computing physically realized OR 7번째 substrate class 추가
- **fixpoint marker**: `nexus-akida-x-sim-bridge-tri-axis-saturation-2026-04-29T08:55:00Z`
- **cross_repo paired**: anima sibling Ω-cycle witness (raw 47 cross-repo-trawl-witness)

### 28 falsifier 핵심 (8+20 합산)

| 카테고리 | falsifier 수 | 핵심 verdict_check |
|---|---|---|
| sim_bridge × Akida (1차) | 8 | QRNG H ≥ 0.99 / bostrom 분류 ≤ chance / Gödel-q 30%+ disagreement / raw 40 PASS / qpu 3-tier latency / weave 인과위반 < 1e-4 / atlas_anu MI / blowup phase7 50× |
| 3-axis JOINT (2차) | 20 | tri-axis 동시 / Bekenstein voxel / Landauer 4-substrate / Putnam-6-class / Gödel halting / bostrom signature / Lawvere split / bisimulation N-step / W₂ < ε / RG fixed-point / Lyapunov critical / I_irr asymmetric / NSA-SDG match / raw 40 dispatch / 10 sim_bridge selftest / blowup phase-7 / honest C3 / saturation marker / cross-repo consistent / graduation deadline |

raw 91 honest C3: 모든 28 falsifier PREREGISTERED — 10 sim_bridge 도구 존재 확인됐지만 Akida 미보유로 hardware F1-F20 미실행.

## nexus 직접 도움 3축

### 1. infra.state host pool 확장

현재 `~/core/.workspace` host pool:
- host.ubu1 (Ryzen 5 9600X + RTX 5070 12GB)
- host.ubu2 (Ryzen 5 9600X + RTX 5070 12GB open-driver)
- host.htz (Hetzner AX102, 32T CPU-only, 124GB)
- gpu.h100 (H100 ×4, RunPod/vast.ai dispatch)

**신규 등재 후보**: `host.rpi5-akida` (neuromorphic-class, ~1W, 16GB RAM, edge-inference 전용).

raw 40 external-host-dispatch-default 의 vendor diversity 확장 — 현재 4 host class (ubu/htz/gpu/mac) 가 전부 von Neumann CPU/GPU. neuromorphic class 첫 진입.

### 2. atlas tier_1_promotions hardware-substrate evidence

현재 atlas substrate witness 는 모두 cloud-API 경유 (IonQ / QuEra / BrainChip Cloud / etc).
이 dev kit = hardware-direct measurement → atlas tier_1 promotion evidence 의 cloud-dependency 0.

raw 47 cross-repo-trawl-witness 호환 — anima own 2 (b) substrate triangulation 과 nexus atlas 의 cross-link 첫 hardware anchor.

### 3. own 2 admin-block bypass (raw 104 'own' 경로)

own 2 strengthening 2026-04-28 status:
- Neuromorphic 0/3 sub-classes (admin-access blocked at all 3 vendors)
- Optical 0/3 sub-classes (admin-access blocked)

raw 104 design-means-end-decoupling-mandate 의 4 경로:
- own (소유): $1.5K capex 1회
- subscribe (구독): Akida Cloud $995/주
- partner-share: BrainChip 파트너십 — long-tail
- mock-deterministic: simulator only — hardware witness 미달

3주 이상 사용 시 own 회수. nexus 의 atlas tier_1 evidence chain 에서 capex amortization.

## nexus.workspace 등재 제안

```hexa
resource host.rpi5-akida "RPi5 + Akida AKD1000 — neuromorphic edge-inference (M.2 B+M, ~1W, 16GB)"
  owner    nexus
  kind     descriptor
  power    ~1W
  capacity ~1.2M neurons (AKD1000)
  host     local-edge (cable-tethered, no cloud)
```

추가 시점: dev kit 도착 + Meta TF 첫 변환 PASS 후 (event-driven 등재, 사전 등재 X per raw 91 C3 honest).

## 못 하는 것 (raw 91 honest C3)

- 학습 dispatch X (inference only) → gpu.h100 / RunPod H100 substitute 불가
- LLM forward X (16GB RAM) → Qwen-7B+ 못 올림
- 일반 PyTorch checkpoint 직접 사용 X (Meta TF quantize 필요)
- nexus kick ω-cycle 의 GPU dispatch path 와 별개 분기 (event-stream-only path)

## 비용 비교

| 옵션 | Capex | Opex | 회수 시점 |
|---|---|---|---|
| Dev Kit 구매 (own) | $1,495 | $0 | 즉시 |
| Akida Cloud 1주 | $0 | $995 | — |
| 1일 trial | $0 | $1 | 적합성 사전 확인용 |

## 결정 기준 (raw 167 multi-interpretation surfacing)

**구매 정당화 조건** (2 중 1+ 충족 시):
- (a) anima own 2 (b) 뉴로모픽 1/3 WITNESSED 가 30일 내 critical path (anima 측 결정 의존)
- (b) atlas tier_1 hardware-substrate evidence 가 Q2 cross-repo trawl 의 결정적 missing anchor

**구매 보류 조건**:
- anima 측 V_phen_GWT 변환 PASS 미확인
- atlas tier_1 cloud-dependency 가 현재 운영상 충분

## 권장 전 단계

1. Akida Cloud 1일 trial ($1) — V_phen_GWT 일부 모듈 변환 가능성 측정
2. BrainChip support 문의 — anima 12-tier backbone + Phi-vector 변환 가능 여부
3. anima 측 own 2 (b) 30일 critical path 진입 확인 후 dev kit 구매 진행

## Pending refire ledger

- `state/pending_kick_refire/2026-04-29_oauth_recovery_refire.jsonl` — kick infra 회복 시 양 토픽 자동 재발사 trigger
- `~/core/hive/state/oauth_revoked_slots/audit.jsonl` — 24/24 OAuth slot quarantine (5 rows, schema v1)
- precondition: ≥1 remote slot live-API PASS

## Cross-link

- raw 40 external-host-dispatch-default (host pool extension)
- raw 47 cross-repo-trawl-witness (anima sister analysis cross-link)
- raw 104 design-means-end-decoupling-mandate (own/subscribe/partner/mock 경로 결정)
- raw 167 design-think-before-implementation-assumption-surfacing (decision criteria 명시)
- anima/docs/akida_dev_kit_evaluation_2026-04-29.md (sister analysis, research perspective)
- ~/core/.workspace `host.*` resource declarations
