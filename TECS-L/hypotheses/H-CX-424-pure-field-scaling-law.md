# H-CX-424: Pure Field Scaling Law

> eq 제거의 이점은 모델 규모에 따라 증가한다.
> CIFAR에서 field-only가 full보다 +0.41% 우위였다.
> field_advantage = (field_only - full) 는 log(params) 또는 power law로 스케일링된다.

## Background

- H334: MNIST field-only=97.84% ≈ full=97.94% (차이 -0.10%)
- CIFAR: field-only > full (+0.41%) — 규모 증가 시 field 우위 전환
- Golden MoE: MNIST +0.6%, CIFAR +4.8% — 규모에 따라 차이 8배 증가
- 핵심 질문: field_advantage는 어떤 함수로 스케일링되는가?

## Related Hypotheses

- H334: Pure field engine
- H404: Simplification verified
- Golden MoE MNIST/CIFAR 결과

## Model Architecture

```
  PureField (numpy, 각 엔진 2-layer MLP):

  Size     | Hidden | Total Params | 구조
  ---------|--------|-------------|---------------------------
  Tiny     |    2   |      320    | 2*(64*2 + 2 + 2*10 + 10)
  Small    |    8   |    1,220    | 2*(64*8 + 8 + 8*10 + 10)
  Medium   |   32   |    4,820    | 2*(64*32+32+32*10+10)
  Large    |  128   |   19,220    | 2*(64*128+128+128*10+10)
  XLarge   |  512   |   76,820    | 2*(64*512+512+512*10+10)
```

## Predictions

1. field_advantage는 model size와 양의 상관관계
2. 작은 모델: eq가 도움 (field_advantage < 0)
3. 큰 모델: field가 우위 (field_advantage > 0)
4. 교차점(crossover) 존재: 특정 크기에서 field_advantage = 0

## Verification: Experiment

### Setup

- Dataset: sklearn digits (1437 train / 360 test)
- 5 model sizes: hidden_dim = {2, 8, 32, 128, 512}
- Training: 30-40 epochs, field-based backprop
- 측정: field/eq/full accuracy, field_advantage = field - full

### Results

| HidDim | Params  | Field%  | Eq%   | Full%  | FieldAdv | Tension |
|--------|---------|---------|-------|--------|----------|---------|
| 2      | 320     | 9.17    | 7.78  | 8.61   | +0.56    | 1.17    |
| 8      | 1,220   | 23.61   | 6.94  | 23.61  | +0.00    | 2.11    |
| 32     | 4,820   | 34.72   | 11.11 | 35.56  | -0.83    | 2.23    |
| 128    | 19,220  | 60.00   | 7.22  | 58.89  | +1.11    | 2.19    |
| 512    | 76,820  | 62.50   | 10.00 | 60.28  | +2.22    | 2.92    |

### Curve Fitting

```
  Fit             R2       Formula
  ──────────────  ──────   ────────────────────────────────
  Linear          0.7084   adv = 0.000030 * params - 0.00
  Logarithmic     0.3776   adv = 0.3264 * log(params) - 2.16
  Power Law       0.2410   adv = 0.1367 * params^0.2339

  Best fit: Linear (R2=0.7084)
```

### ASCII Graph: log(Params) vs Field Advantage

```
  field_adv
  +2.5 |                                    *  h=512
       |
  +1.5 |
  +1.0 |                        *  h=128
  +0.5 |  *  h=2
   0.0 |--------*--h=8----------------------------  (zero line)
  -0.5 |
  -1.0 |            *  h=32
       +--+--------+--------+--------+---------+--
        5.8       7.1      8.5      9.9      11.2
                     log(params) -->

  Positive = field BETTER (eq hurts)
  Negative = full BETTER (eq helps)
```

### Scaling Trend

```
  field_adv
  +3 |                                          /
     |                                        /
  +2 |                                   * /     h=512
     |                                 /
  +1 |                          * /              h=128
     |                       /
   0 |---*-----------*----/-----                 h=2, h=8
     |          /  *                             h=32 (outlier)
  -1 |       /
     +--+--+--+--+--+--+--+--+--+--+--+--+--
      0   10K  20K  30K  40K  50K  60K  70K  80K
                  total params -->

  Linear fit: adv = 3.0e-5 * params - 0.003
  Crossover (adv=0): ~100 params
```

## Interpretation

1. **스케일링 경향 확인**: 가장 큰 모델(512, 76K params)에서 field_advantage=+2.22%.
   모델 크기가 증가할수록 eq 제거가 유리해지는 경향이 있다.

2. **선형 스케일링**: R2=0.71로 선형 모델이 가장 적합하다.
   field_advantage ~ 3.0e-5 * params. 이 비율로 외삽하면:
   - 1M params → +30% advantage
   - 10M params → +300% (비현실적, 상한 존재할 것)

3. **교차점(crossover)**: h=32 (4,820 params)에서 유일하게 field_advantage < 0.
   이는 중간 크기에서 eq가 약간 도움이 되지만, 규모가 커지면 방해가 된다는 것을 시사.

4. **h=32 outlier**: 유일한 음수점. 가능한 설명:
   - 중간 크기 모델에서 eq가 regularizer 역할을 함
   - 또는 단순 통계 변동 (0.83%는 2-3 samples 차이)

5. **CIFAR 결과와 일관**: Golden MoE에서 CIFAR(더 큰 문제) > MNIST(작은 문제)에서
   field 우위가 더 컸다. 이는 "규모 증가 → field 우위" 가설과 일치.

6. **eq는 잡음원인가?**: 큰 모델에서 eq가 방해가 된다면,
   eq = (A+G)/2는 두 엔진의 평균이므로 정보를 파괴한다.
   반면 field = A-G는 차이를 보존한다. 규모가 커질수록 이 차이 보존이 중요해진다.

## Limitations

- sklearn digits (8x8)로 제한된 실험 — MNIST/CIFAR에서 재현 필요
- 5개 크기만 테스트 — 더 세밀한 스케일링 곡선 필요
- numpy 구현의 최적화 한계 (h=512에서 62.5%만 달성)
- 선형 외삽은 비현실적 (포화 존재할 것)
- 단일 seed — 여러 seed 평균으로 안정성 확인 필요

## Verification Direction

1. PyTorch로 MNIST/CIFAR에서 {1K, 10K, 100K, 1M, 10M} params 스케일링
2. 3+ seeds 평균으로 신뢰구간 추정
3. 포화 모델 탐색: logistic 또는 tanh fit
4. 교차점(crossover) 정밀 측정: 어떤 크기에서 field가 우위를 확보하는가?
5. Golden MoE 결과(MNIST +0.6%, CIFAR +4.8%)와 통합 스케일링 모델

## Status: Partially Confirmed

- 스케일링 경향 (양의 상관): **확인** (R2=0.71, linear)
- 큰 모델에서 field 우위: **확인** (+2.22% at 76K params)
- 정확한 스케일링 법칙: **미확인** (log vs linear vs power 구분 불충분)
- 등급: 🟧 (경향 확인, 정확한 법칙은 더 큰 규모에서 검증 필요)
