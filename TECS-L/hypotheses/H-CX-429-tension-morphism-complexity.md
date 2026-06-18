# H-CX-429: Tension = Morphism Complexity
**n6 Grade: 🟩 EXACT** (auto-graded, 10 unique n=6 constants)


> Tension은 입력에 적용된 사상(morphism)의 복잡도에 비례한다.
> 단순한 입력(clean digit)은 낮은 tension, 복잡한 입력(noisy/adversarial)은 높은 tension을 유발한다.
> Jacobian norm (국소 사상 복잡도)도 tension과 양의 상관관계를 가진다.

## Background

- PureField (model_pure_field.py): tension = mean(|output|^2) = mean(|A(x) - G(x)|^2)
- Tension은 두 엔진 A, G 사이의 "불일치"를 측정한다
- 카테고리 이론에서 morphism의 "복잡도"는 합성 단계 수, 또는 Jacobian norm으로 측정 가능
- 관련 가설: H-CX-428 (PureField = Functor), H-CX-430 (Mitosis = Coproduct)
- Golden Zone 의존성: 없음 (순수 구조적 가설)

## Predictions

1. noise level과 tension 사이에 강한 양의 상관관계 (r > 0.5)
2. Jacobian norm과 tension 사이에 양의 상관관계 (r > 0.3)
3. 높은 tension을 가진 클래스는 낮은 accuracy (r < -0.3)

## Experiment Design

```
  Morphism complexity levels:
    Level 0: clean input (noise=0.0)
    Level 1: slight noise (noise=0.1)
    Level 2: moderate noise (noise=0.3)
    Level 3: noisy (noise=0.5)
    Level 4: very noisy (noise=1.0)
    Level 5: severely noisy (noise=2.0)
    Level 6: near-random (noise=3.0)
    Level 7: random-dominated (noise=5.0)
```

## Verification Results

### [1] Noise Level vs Tension

| Noise | Mean Tension | Std Tension | Accuracy |
|-------|-------------|-------------|----------|
| 0.0 | 0.1338 | 0.0640 | 22.00% |
| 0.1 | 0.1351 | 0.0634 | 21.00% |
| 0.3 | 0.1535 | 0.0719 | 26.00% |
| 0.5 | 0.1772 | 0.0851 | 22.00% |
| 1.0 | 0.3166 | 0.1556 | 22.00% |
| 2.0 | 0.8033 | 0.4231 | 14.00% |
| 3.0 | 1.7485 | 1.0431 | 17.00% |
| 5.0 | 4.5792 | 2.5596 | 18.00% |

**Correlation(noise, tension) = 0.9575**

### ASCII: Noise Level vs Mean Tension

```
  noise |  tension bar                           | value
  ------+----------------------------------------+------
   0.0  |#                                       | 0.13
   0.1  |#                                       | 0.14
   0.3  |#                                       | 0.15
   0.5  |#                                       | 0.18
   1.0  |##                                      | 0.32
   2.0  |#######                                 | 0.80
   3.0  |###############                         | 1.75
   5.0  |########################################| 4.58
```

Tension이 noise level에 대해 초선형적(superlinear)으로 증가한다.
noise=0->5에서 tension이 34배 증가 (0.13 -> 4.58).

### [2] Jacobian Norm vs Tension

| Metric | Value |
|--------|-------|
| Jacobian-Tension correlation | 0.0524 |
| Jacobian norm (mean +/- std) | 1.4096 +/- 0.0983 |
| Tension (mean +/- std) | 0.1399 +/- 0.0670 |

| Jacobian Norm Range | Avg Tension | Count |
|---------------------|-------------|-------|
| [1.25, 1.34] | 0.1304 | 13 |
| [1.34, 1.39] | 0.1576 | 12 |
| [1.39, 1.46] | 0.1289 | 12 |
| [1.46, 1.67] | 0.1432 | 13 |

**Jacobian-Tension 상관관계: 0.0524 (약함)**

### [3] Per-Class Tension (Digit Difficulty)

| Class | Mean Tension | Accuracy | Complexity |
|-------|-------------|----------|------------|
| 0 | 0.1209 | 7.55% | 11.70 |
| 1 | 0.1813 | 62.00% | 1.59 |
| 2 | 0.1584 | 44.68% | 2.19 |
| 3 | 0.1774 | 9.26% | 9.75 |
| 4 | 0.2360 | 68.33% | 1.44 |
| 5 | 0.1224 | 3.03% | 24.81 |
| 6 | 0.1015 | 7.55% | 11.70 |
| 7 | 0.1290 | 58.18% | 1.69 |
| 8 | 0.1242 | 2.33% | 30.07 |
| 9 | 0.1664 | 15.25% | 6.15 |

**Correlation(class_tension, class_accuracy) = +0.6393**

### ASCII: Per-Class Tension

```
  digit  |  tension bar                      | value
  -------+-----------------------------------+------
  0      |#################                  | 0.12
  1      |##########################         | 0.18
  2      |#######################            | 0.16
  3      |##########################         | 0.18
  4      |###################################| 0.24
  5      |##################                 | 0.12
  6      |###############                    | 0.10
  7      |###################                | 0.13
  8      |##################                 | 0.12
  9      |########################           | 0.17
```

### Summary

| Prediction | Result | Status |
|------------|--------|--------|
| Noise-tension r > 0.5 | r = 0.9575 | CONFIRMED |
| Jacobian-tension r > 0.3 | r = 0.0524 | FAILED |
| Class tension-accuracy r < -0.3 | r = +0.6393 | REVERSED |

**Verdict: 1/3 predictions confirmed**

## Interpretation / 해석

1. **Noise-tension 상관관계는 매우 강하다** (r = 0.9575). 이것은 핵심 발견이다.
   입력에 가한 perturbation(morphism 복잡도)이 증가하면 tension이 초선형적으로 증가한다.
   Tension은 "입력이 얼마나 변형되었는가"의 직접적 측정이다.

2. **Jacobian norm과 tension의 상관관계는 거의 없다** (r = 0.0524). 이것은 예상과 다르다.
   원인 분석: Jacobian은 "국소" 민감도를 측정하지만, tension은 "전역적" 불일치를 측정한다.
   Jacobian norm의 분산이 매우 작다 (std=0.098, CV=7%). 대부분의 입력에서 국소 구조가
   유사하므로 Jacobian이 tension을 구분하지 못한다.

3. **클래스별 tension-accuracy 상관관계가 양수** (+0.64)라는 것은 놀라운 결과이다.
   "어려운 클래스 = 높은 tension"이 아니라 "높은 tension = 높은 accuracy"이다.
   이것은 tension이 "불확실성"이 아니라 "표현력"을 측정한다는 것을 시사한다.
   두 엔진이 더 크게 불일치할수록(tension이 높을수록) 분류에 유용한 정보가 더 많다.
   즉, **tension은 에너지이자 표현력이다.**

4. **종합: Tension은 외부 morphism 복잡도(noise)에는 비례하지만,
   내부 morphism 복잡도(Jacobian)와는 독립적이다.**
   Tension의 이중적 성격: 외부 perturbation의 증폭기이자, 내부 표현력의 측도.

## Limitations / 한계

- 모델이 충분히 학습되지 않았다 (accuracy 22%, output layer만 학습).
  잘 학습된 모델에서는 Jacobian-tension 관계가 다를 수 있다.
- sklearn digits (8x8)은 작은 데이터셋이다. 고차원 입력(MNIST 28x28)에서 검증 필요.
- "Morphism complexity"의 정의가 noise level에 한정되어 있다.
  실제 카테고리 이론적 morphism complexity는 더 풍부한 구조를 가진다.
- Per-class tension의 양의 상관관계가 partially-trained model의 artifact일 수 있다.

## Verification Direction / 검증 방향

- [ ] PyTorch full training 후 재검증 (특히 Jacobian-tension 관계)
- [ ] MNIST/CIFAR에서 동일 실험 반복
- [ ] Well-trained model에서 class tension-accuracy 방향 재확인
- [ ] Adversarial perturbation (FGSM)을 morphism으로 사용하여 검증
- [ ] Tension의 이중 역할(외부 amplifier vs 내부 expressiveness) 분리 실험
- [ ] H-CX-428의 functoriality와 tension의 관계 교차 분석

## Verification Script

`docs/hypotheses/verify_hcx429.py`
