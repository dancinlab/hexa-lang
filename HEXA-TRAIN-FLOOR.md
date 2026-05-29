@title: 🐢 HEXA-TRAIN-FLOOR — "거북이 학습기 바닥"
@goal: hexa-native 학습기를 production scale에서 feasible하게 — step-rate floor를 물리 한계(roofline)까지 끌어올려 closure. 추론은 AKIDA-int4 순수 유지(g1), 학습 경로만 대상.

# HEXA-TRAIN-FLOOR — current state

hexa-native 트레이너 throughput이 production scale에서 🔴 INFEASIBLE.
DECODER M5 STEP_RATE_LOG 실측 기준 baseline:

| 지표 | 값 | 의미 |
|---|---|---|
| step-rate | 0.28 step/s (1.99 s/step) | 너무 느림 |
| production 환산 | 77~122 GPU-days | 사실상 1회 학습 불가 |
| GPU util | 0~8% | compute 아님 — sync/메모리 병목 |
| 판정 | 🔴 INFEASIBLE | scale에서 hexa-native 학습 막힘 |

## 근본 원인 (2축)

1. **RSS churn** — step마다 200~325MB 할당/해제. AdamW 별개 source, CUDA/runtime-side로 확정 (anima trainer 결백).
2. **작은 행렬 GPU↔CPU sync** — d=64에선 cuBLAS 계산보다 sync 왕복 오버헤드가 큼.

## 적용했으나 역효과난 fix

hexa-lang #2017(AdamW in-place) + #2018(cuBLAS gemv) 적용 후 → 0.156~0.18 step/s
(baseline보다 ~3× 느려짐). 원인 = "d=64에선 GPU sync 비용 > cuBLAS 절약" — hexa-lang #1354 예측 적중.

## 경계 (변경 금지)

- 추론 = AKIDA-int4 순수 유지 (g1 핵심).
- 학습만 PyTorch 우회 가능 (CLM d5/B0 트랙). 이 도메인은 hexa-native 학습 경로 자체의 floor를 다룸.

## milestones

- [x] M1 RSS churn 200~325MB/step source localize — AdamW 外 CUDA/runtime-side 지점 특정
- [ ] M2 작은 행렬(d=64) GPU↔CPU sync 오버헤드 제거 — fused/batched dispatch or d-threshold 게이팅
- [ ] M3 #2017/#2018 회귀 분석 — 왜 3× 느려졌나, cuBLAS gemv를 d-threshold로 조건부 활성
- [ ] M4 step-rate floor 측정 — roofline 기준 물리 천장 산출 (끝 = 100% 아닌 물리 한계)
- [ ] M5 PyTorch 대비 throughput parity 측정대 구축 — A/B 측정 + verdict 영속
