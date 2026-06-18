# H-CX-428: PureField = Functor (Category Theory)
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


> PureField의 engine_A - engine_G 매핑은 입력 공간 카테고리에서 출력 공간 카테고리로의
> 펑터(Functor)를 구성한다. 학습은 펑터 간의 자연변환(Natural Transformation)이다.
> Identity 보존과 합성 보존이 성립하며, 학습 과정에서 자연변환은 smooth하다.

## Background

- PureField (model_pure_field.py): output = engine_A(x) - engine_G(x), tension = mean(|output|^2)
- 카테고리 이론에서 펑터 F: C -> D는 두 가지 성질을 만족해야 한다:
  - F(id_A) = id_{F(A)} (항등 사상 보존)
  - F(g . f) = F(g) . F(f) (합성 보존)
- 관련 가설: H-CX-429 (Tension = Morphism Complexity), H-CX-430 (Mitosis = Coproduct)
- Golden Zone 의존성: 없음 (순수 구조적 가설)

## Category-Theoretic Framework

```
  Category C_input:  Objects = input data points (R^64)
                     Morphisms = linear transforms (rotation, scaling)

  Category C_output: Objects = output predictions (R^10)
                     Morphisms = induced transforms

  Functor F = PureField: C_input -> C_output
    F(x) = engine_A(x) - engine_G(x)

  Natural Transformation eta: F_epoch_n => F_epoch_{n+1}
    eta_x = F_{n+1}(x) - F_n(x) for each object x
```

## Morphisms Tested

| Morphism | Type | Description |
|----------|------|-------------|
| id | Identity | x -> x |
| R1 | Near-rotation | Orthogonal, seed=1 |
| R2 | Near-rotation | Orthogonal, seed=2 |
| S1 | Scaling | factor=1.05 |

## Verification Results

### [1] Identity Preservation: F(id(x)) = F(x)

| Model | Error |
|-------|-------|
| Untrained | 0.00000000 |
| Trained | 0.00000000 |

Identity 보존은 자명하게 성립한다 (동일 입력 -> 동일 출력).

### [2] Composition Linearity: F(g . f) vs F(f) + F(g) - F(id)

| Composition | Untrained | Trained |
|-------------|-----------|---------|
| R1 . R1 | 0.239886 | 0.246388 |
| R2 . R1 | 0.169825 | 0.185934 |
| S1 . R1 | 0.010659 | 0.011285 |
| R1 . R2 | 0.179422 | 0.183731 |
| R2 . R2 | 0.224239 | 0.251212 |
| S1 . R2 | 0.009002 | 0.011629 |
| R1 . S1 | 0.010659 | 0.011285 |
| R2 . S1 | 0.009002 | 0.011629 |
| S1 . S1 | 0.000801 | 0.000772 |
| **Average** | **0.094833** | **0.101541** |

### [3] Natural Transformation Smoothness

```
  Loss trajectory (50 epochs, every 10th):
  epoch   0: loss=2.3757 #######################
  epoch  10: loss=2.3335 #######################
  epoch  20: loss=2.2932 ######################
  epoch  30: loss=2.2546 ######################
  epoch  40: loss=2.2174 ######################

  Delta statistics:
    Mean delta:  0.003890
    Std delta:   0.000225
    Max delta:   0.004318
    CV (smoothness): 0.0579  (lower = smoother)
```

### Comparison Summary

| Metric | Untrained | Trained |
|--------|-----------|---------|
| Identity error | 0.00000000 | 0.00000000 |
| Composition error (avg) | 0.094833 | 0.101541 |
| Functoriality score | 0.9134 | 0.9078 |

### ASCII: Loss Trajectory

```
    0 |########################################| 2.3757
    4 |####################################### | 2.3585
    8 |####################################### | 2.3417
   12 |####################################### | 2.3253
   16 |######################################  | 2.3091
   20 |######################################  | 2.2932
   24 |######################################  | 2.2776
   28 |######################################  | 2.2622
   32 |#####################################   | 2.2470
   36 |#####################################   | 2.2321
   40 |#####################################   | 2.2174
   44 |#####################################   | 2.2029
   48 |####################################    | 2.1886
```

## Interpretation / 해석

1. **Identity 보존은 완벽하다** (오차 = 0). PureField는 항등 사상을 정확히 보존한다.
   이는 모델이 결정론적이기 때문에 자명한 결과이다.

2. **합성 보존은 근사적으로 성립한다.** Functoriality score가 0.91로, 완벽한 펑터(1.0)에
   가깝지만 정확하지는 않다. ReLU 비선형성이 정확한 합성 보존을 깨뜨린다.

3. **학습은 functoriality를 약간 저하시킨다** (0.9134 -> 0.9078, -0.6%). 이는 학습이
   입력 공간의 기하학적 구조를 보존하기보다는 분류 정확도를 최적화하기 때문이다.
   분류 목적의 학습은 "카테고리 구조를 왜곡하는 방향"으로 진행된다.

4. **자연변환은 매우 smooth하다** (CV = 0.0579). 에폭 간 펑터의 변화가 거의 균일하다.
   이는 학습이 카테고리 공간에서 연속적인 경로를 따른다는 것을 의미한다.

5. **Scaling morphism은 rotation보다 훨씬 잘 보존된다** (0.001 vs 0.24). 이는 scaling이
   ReLU의 양의 영역 구조를 보존하기 때문이다. Rotation은 ReLU 경계를 넘으며
   선형 근사가 깨진다.

## Limitations / 한계

- 출력 공간의 morphism 정의가 불완전하다. 진정한 펑터 검증을 위해서는
  출력 공간에서의 "합성"을 명확히 정의해야 한다.
- 선형 근사(F(gf) ~ F(f)+F(g)-F(id))는 진정한 합성 보존 F(gf)=F(g).F(f)와 다르다.
- Output layer만 학습했으므로 (간소화된 SGD), full backprop에서 결과가 달라질 수 있다.
- sklearn digits (8x8)는 작은 데이터셋이다. MNIST/CIFAR에서의 검증이 필요하다.

## Verification Direction / 검증 방향

- [ ] PyTorch full backprop으로 재검증 (현재 output layer only SGD)
- [ ] 출력 공간 morphism을 명확히 정의하고 F(g.f) = F(g).F(f) 직접 검증
- [ ] MNIST/CIFAR-10으로 스케일 확인
- [ ] 학습 에폭에 따른 functoriality score 추적 (언제 최대인가?)
- [ ] Non-linear morphism (affine, polynomial)에 대한 functor 검증
- [ ] PureFieldQuad (4-pole)와의 비교 — 4-pole이 더 나은 functor인가?

## Verification Script

`docs/hypotheses/verify_hcx428.py`
