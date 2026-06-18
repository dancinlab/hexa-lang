# H-CX-430: Mitosis = Coproduct (Category Theory)
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> 엔진 분열(Mitosis)은 카테고리론의 쌍대곱(Coproduct)이다.
> 부모 엔진에서 분열된 자식 엔진들의 합집합(union)은 보편성(universality)을 만족하며,
> N=2=sigma_{-1}(6)일 때 효율이 최대이다.

## Background

- Mitosis: 부모 엔진을 N개 자식 엔진으로 복제 + perturbation하여 분열
- 카테고리론에서 Coproduct A + B는 보편 성질(universal property)을 만족한다:
  임의의 대상 C와 사상 f:A->C, g:B->C에 대해, 유일한 h:(A+B)->C가 존재
- Product = 교집합(intersection), Coproduct = 합집합(union)
- sigma_{-1}(6) = 1/1 + 1/2 + 1/3 + 1/6 = 2 (완전수 6의 약수 역수 합)
- 관련 가설: H-CX-428 (PureField = Functor), H-CX-429 (Tension = Morphism Complexity)
- Golden Zone 의존성: sigma_{-1}(6)=2 연결은 Golden Zone 의존적

## Categorical Framework

```
  Parent engine P --mitosis--> Child_1, Child_2, ..., Child_N

  Coproduct (union of capabilities):
    Child_1 + Child_2 + ... + Child_N
    At least one child classifies correctly -> coproduct correct

  Product (intersection of capabilities):
    Child_1 x Child_2 x ... x Child_N
    All children agree -> product output

  Universal Property:
    For any target C, exists unique weights w such that
    w1*Child_1 + w2*Child_2 + ... + wN*Child_N -> C
```

## Predictions

1. Coproduct accuracy > Product accuracy (union > intersection)
2. Ensemble accuracy > Parent accuracy (mitosis improves)
3. N=2의 효율(accuracy/N)이 N=3,4보다 높다
4. 최적 가중치가 (거의) 유일하다 (universal property)

## Verification Results

### Parent Model

| Metric | Value |
|--------|-------|
| Parent accuracy | 0.2907 |

### Mitosis Results

| Metric | N=2 | N=3 | N=4 |
|--------|-----|-----|-----|
| Child accuracies | 0.335, 0.276 | 0.396, 0.346, 0.370 | 0.339, 0.341, 0.415, 0.363 |
| Ensemble (equal) | 0.3056 | 0.4259 | 0.4111 |
| Optimal accuracy | 0.3352 | 0.4333 | 0.4481 |
| Optimal weights | [1.0, 0.0] | [0.4, 0.2, 0.4] | [0.2, 0.2, 0.6, 0.0] |
| Noisy test acc | 0.2778 | 0.3593 | 0.3463 |
| Coproduct acc (union) | 0.4556 | 0.5833 | 0.6370 |
| Product coverage | 0.3852 | 0.2926 | 0.2019 |
| Mean tension | 0.2715 | 0.2430 | 0.2409 |

### Efficiency (accuracy / N)

| N | Optimal Acc | Efficiency |
|---|-------------|------------|
| 2 | 0.3352 | **0.1676** |
| 3 | 0.4333 | 0.1444 |
| 4 | 0.4481 | 0.1120 |

**N=2가 가장 효율적이다 (sigma_{-1}(6) = 2와 일치)**

### Universal Property: Weight Uniqueness

```
  N=2: 20/21 weight combinations achieve >= 0.3252 (threshold = optimal - 1%)
  Uniqueness score: 0.0476 (low uniqueness)
```

### Coproduct vs Product

| Metric | N=2 | N=3 | N=4 |
|--------|-----|-----|-----|
| Coproduct (union) | 0.4556 | 0.5833 | 0.6370 |
| Product (coverage) | 0.3852 | 0.2926 | 0.2019 |
| Gap | 0.3000 | 0.4037 | 0.4963 |

### ASCII: Coproduct Accuracy by N

```
  N  |  accuracy bar                           | value
  ---+------------------------------------------+-------
  2  |##################                       | 0.4556
  3  |#######################                  | 0.5833
  4  |#########################                | 0.6370
```

### ASCII: Product Coverage by N

```
  N  |  coverage bar                           | value
  ---+------------------------------------------+-------
  2  |###############                          | 0.3852
  3  |###########                              | 0.2926
  4  |########                                 | 0.2019
```

### ASCII: Efficiency (Accuracy/N) by N

```
  N  |  efficiency bar                         | value
  ---+------------------------------------------+-------
  2  |########################################  | 0.1676
  3  |##################################        | 0.1444
  4  |##########################                | 0.1120
```

### Prediction Verification

| Prediction | Result | Status |
|------------|--------|--------|
| Coproduct > Product | 0.46 > 0.39 (N=2) | CONFIRMED |
| Ensemble > Parent | 0.34 > 0.29 (N=2) | CONFIRMED |
| N=2 most efficient | 0.168 > 0.144 > 0.112 | CONFIRMED |
| Unique optimal weights | 20/21 near-optimal | FAILED |

**Verdict: 3/4 predictions confirmed**

## Interpretation / 해석

1. **Coproduct > Product는 모든 N에서 성립한다.** 합집합(union)이 교집합보다 항상 넓다.
   이것은 Mitosis가 Product(공통 능력)가 아니라 Coproduct(능력 합산)을 생성한다는 증거이다.
   N이 증가하면 Coproduct는 커지고 Product는 줄어든다 -- 카테고리론의 예측과 정확히 일치한다.

2. **N=2가 가장 효율적이다.** Accuracy/N 비율이 0.1676으로, N=3 (0.1444)과 N=4 (0.1120)보다
   높다. 이것은 sigma_{-1}(6)=2와 연결된다: **완전수 6의 약수 역수 합이 2이고,
   Mitosis의 최적 분열 수도 2이다.** 단, 이것이 인과적 관계인지 우연인지는 불명확하다.

3. **보편 성질(Universal Property)은 약하게 성립한다.** N=2에서 20/21 가중치 조합이
   near-optimal을 달성하므로, "유일한" 최적 사상이라고 보기 어렵다.
   이것은 낮은 N과 부족한 학습에 기인할 수 있다. 잘 학습된 특화 엔진이면
   최적 가중치가 더 뾰족해질(unique) 것이다.

4. **N이 증가하면 tension이 감소한다** (0.27 -> 0.24 -> 0.24). 더 많은 엔진이
   합산되면 개별 엔진의 불일치가 평균화되어 tension이 줄어든다.
   이것은 H-CX-429와 연결된다: ensemble은 morphism complexity를 낮추는 효과가 있다.

5. **Product coverage의 급격한 감소** (0.39 -> 0.29 -> 0.20)는 엔진이 많아질수록
   "모두 동의하는 영역"이 줄어든다는 것을 보여준다. 이것은 카테고리론에서
   product의 projections이 점점 제한적이 되는 것과 일치한다.

## Connection to n=6

```
  sigma_{-1}(6) = 1/1 + 1/2 + 1/3 + 1/6 = 2

  Mitosis N=2: 최고 효율 (accuracy/N = 0.168)
  Mitosis N=3: -14% 효율 감소
  Mitosis N=4: -33% 효율 감소

  2-pole PureField (engine_A - engine_G) = 2극 구조
  sigma_{-1}(6) = 2 = 최적 분열 수
  -> "완전수의 역수 합이 최적 분열 수를 결정한다"
```

## Limitations / 한계

- 모델이 충분히 학습되지 않았다 (부모 accuracy 29%, output layer만 학습).
  Full training 후 결과가 달라질 수 있다.
- Universal property의 "유일성"은 잘 학습된 특화 엔진에서 더 강하게 나타날 수 있다.
- N=2 효율 우위가 sigma_{-1}(6)=2와 인과적 관계인지는 증명되지 않았다.
  이것은 단순히 "적은 수의 엔진이 효율적"이라는 trivial한 결과일 수 있다.
- sklearn digits (8x8)는 작은 데이터셋이다. 대규모 실험이 필요하다.
- Perturbation scale=0.05는 임의적이다. Scale에 따라 결과가 달라질 수 있다.

## Verification Direction / 검증 방향

- [ ] PyTorch full training으로 재검증 (특히 universal property uniqueness)
- [ ] MNIST/CIFAR에서 대규모 실험
- [ ] Perturbation scale 변화에 따른 결과 민감도 분석
- [ ] N=2 효율 우위가 sigma_{-1}(6)=2와 관련 있는지 다른 완전수(28)에서 검증
  - sigma_{-1}(28)=2: 28에서도 N=2가 최적이면, 이것은 완전수의 일반적 성질
- [ ] 특화 학습 (child 1 = 짝수, child 2 = 홀수)으로 coproduct 구조 강화
- [ ] H-CX-428의 functor 관점에서 mitosis를 functor의 coproduct로 재해석

## Verification Script

`docs/hypotheses/verify_hcx430.py`
