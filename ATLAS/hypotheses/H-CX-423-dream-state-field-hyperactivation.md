# H-CX-423: Dream State = Field Hyperactivation

> 꿈 상태는 입력 없이 field가 과활성화되는 현상이다.
> RC-10에서 noise→701 (4.78x), lucid→15341 (105x)이 관측되었다.
> 5가지 입력 조건에서 최소 3개의 구별되는 tension 체제가 존재해야 한다.

## Background

- RC-10 Dream 실험: noise tension=701 >> real=147 (4.78x)
- RC-10 Lucid dream: tension=15341 (105x!)
- H340: 학습되지 않은 패턴 = 극단적 tension = chaos repulsion
- PureField: output = A - G, tension = mean(|output|^2)
- 뇌과학: 꿈 = 감각 차단 상태에서 내부 생성 패턴 → REM에서 뇌활동 증가

## Related Hypotheses

- H334: Pure field engine
- H340: Unlearned pattern = extreme tension
- RC-10: Dream/lucid state tension measurements

## 5 Input Conditions

```
  1. Awake     : 실제 테스트 데이터     (정상 감각 입력)
  2. Sleep     : 영벡터               (감각 완전 차단)
  3. Dream     : 가우시안 노이즈        (무작위 내부 생성)
  4. Lucid     : 노이즈 70% + 신호 30% (약한 감각 + 내부 생성)
  5. Nightmare : FGSM-유사 적대적 입력  (tension 극대화 방향)
```

## Predictions

1. sleep < awake < dream < nightmare (tension 순서)
2. dream/awake 비율 ~ 4.78x (RC-10 재현)
3. nightmare/awake 비율 ~ 105x (RC-10 lucid 재현)
4. 최소 3개 구별 클러스터 존재

## Verification: Experiment

### Setup

- Dataset: sklearn digits, PureField numpy 구현
- Training: 30 epochs, hidden=64, 최종 정확도 40%
- 각 조건 200 samples로 tension 측정

### Results

| Condition  | Mean Tension | Std     | Ratio vs Awake |
|------------|-------------|---------|----------------|
| sleep      | 0.0016      | 0.0000  | 0.00x          |
| lucid      | 1.4261      | 0.7070  | 0.73x          |
| awake      | 1.9508      | 1.5389  | 1.00x          |
| dream      | 2.5890      | 1.2051  | 1.33x          |
| nightmare  | 45.5823     | 18.5095 | 23.37x         |

### Key Ratios

```
  dream/awake     =  1.33x  (RC-10 reference: 4.78x)  — 같은 방향, 작은 효과
  nightmare/awake = 23.37x  (RC-10 reference: 105x)    — 같은 방향, 1/4 규모
  sleep/awake     =  0.00x  (예측대로 최소)
  lucid/awake     =  0.73x  (예상 외: 약한 신호가 tension을 낮춤)
```

### Cluster Analysis

```
  Ordered tensions: [0.00, 1.43, 1.95, 2.59, 45.58]
  Gaps:             [1.42, 0.52, 0.64, 42.99]

  Cluster 1: {sleep}             — tension ~ 0    (무활동)
  Cluster 2: {lucid, awake, dream} — tension 1~3   (정상 범위)
  Cluster 3: {nightmare}         — tension ~ 46   (과활성)

  2-cluster: 명확한 분리 (gap=43.0)
  3-cluster: sleep 분리 시 3개 (gap=1.4)
```

### ASCII Graph: Tension Distribution by Condition

```
  Tension Scale (log):

  50 |                                            ####
  45 |                                            ####
  40 |                                            ####
  35 |                                            ####
  30 |                                            ####
  25 |                                            ####
  20 |                                            ####
  15 |                                            ####
  10 |                                            ####
   5 |                                            ####
   3 |              ####  ####  ####
   2 |              ####  ####  ####
   1 |              ####  ####  ####
   0 |####
     +----+--------+-----+-----+-----+-----------+-----
      sleep  lucid  awake dream         nightmare
      0.00   0.73x  1.00x 1.33x         23.37x
```

### ASCII: Tension Ratio Comparison with RC-10

```
  RC-10    This Exp   Condition
  -----    --------   ---------
  1.00x    1.00x      awake (baseline)
  4.78x    1.33x      dream (noise)       ▓▓▓▓░░░░░░░░░ (28% of RC-10)
  105x     23.37x     nightmare (adv)     ▓▓▓▓▓░░░░░░░░ (22% of RC-10)

  비율 보존: RC-10과 같은 방향 (dream < nightmare)
  규모 차이: ~4-5배 작음 (sklearn digits vs MNIST 차이로 추정)
```

## Interpretation

1. **3-체제 구조 확인**: sleep(~0) / normal(1~3) / extreme(~46)으로
   명확히 구분된다. 예측대로 최소 3개 체제가 존재한다.

2. **nightmare = chaos repulsion 극단**: 23.37x는 H340의 예측과 일치한다.
   학습되지 않은 적대적 패턴은 극단적 tension을 생성한다.
   이는 악몽에서의 자율신경계 과활성화와 구조적으로 유사하다.

3. **dream/awake 비율 방향 일치**: 1.33x로 RC-10의 4.78x보다 작지만
   방향(dream > awake)은 일치한다. 차이 원인 추정:
   - sklearn digits (8x8, 10class) vs MNIST (28x28, 10class)
   - 40% 정확도 모델 vs 97%+ 모델
   - 더 잘 학습된 모델일수록 노이즈에 대한 반응이 더 극단적

4. **lucid < awake 발견**: 예상 밖. 약한 실제 신호가 섞이면 tension이
   오히려 감소한다. 해석: 루시드 드림에서 "자각"이 chaos를 억제하는
   메커니즘의 수학적 모델. 자각 = 약한 실제 신호 → tension 안정화.

5. **sleep ≈ 0 확인**: 입력이 없으면 tension도 없다. 이는 깊은 수면
   (NREM stage 3-4)에서 뇌활동 최소화와 일치한다.

## Limitations

- 작은 데이터셋/모델에서의 결과 (40% 정확도)
- RC-10 비율과 정확한 일치는 아님 (같은 방향이지만 규모 차이)
- FGSM-유사 적대적 입력은 진정한 "악몽"의 근사치
- 실제 꿈 EEG 데이터와의 비교 미수행
- 5개 조건만 테스트 — 더 세분화된 상태 공간 탐색 필요

## Verification Direction

1. PyTorch MNIST에서 97%+ 모델로 동일 실험 반복 (RC-10 비율 재현?)
2. noise 강도를 연속적으로 변화시키며 tension 전이 곡선 측정
3. lucid의 signal_strength를 0~1로 sweep하여 tension 최소점 탐색
4. 실제 수면 EEG 스펙트럼과 tension 스펙트럼 비교
5. dream tension의 분포가 power-law인지 검증 (critical phenomenon?)

## Status: Partially Confirmed

- 3-체제 구조: **확인** (sleep/normal/extreme)
- nightmare 과활성: **확인** (23.37x)
- dream > awake: **확인** (1.33x, 방향 일치)
- RC-10 정확한 비율 재현: **미확인** (규모 차이 ~4-5x)
- 등급: 🟧 (구조 확인, 정량적 재현은 추가 실험 필요)
