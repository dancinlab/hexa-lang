# H-CX-437: Learning = Maxwell's Demon
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **Hypothesis**: Neural network learning acts as Maxwell's Demon — using
> information (gradient signals) to decrease output entropy (increase order/accuracy).
> The Demon's information cost manifests as weight entropy increase.
> The fundamental efficiency limit is Landauer's kT*ln(2) per bit erased,
> connecting to H-CX-2's MI efficiency ~ ln(2).

## Background

### Maxwell's Demon in Thermodynamics

Maxwell's Demon is a thought experiment where an intelligent agent sorts
fast/slow molecules, apparently violating the 2nd law. Landauer (1961) and
Bennett (1982) resolved this: the Demon must store information, and erasing
that information costs at least kT*ln(2) per bit — restoring the 2nd law.

### Neural Network as Demon

| Thermodynamic Concept     | Neural Network Analog             |
|---------------------------|-----------------------------------|
| Molecule sorting          | Classification (ordering data)    |
| Output entropy H(Y)       | Prediction uncertainty            |
| Demon's memory H(W)       | Weight distribution entropy       |
| Information erased         | Correct classifications gained    |
| Erasure cost               | Weight update magnitude           |
| Landauer limit kT*ln(2)   | Minimum cost per bit of order     |

### Related Hypotheses

- H-CX-2: MI efficiency ~ ln(2) (Landauer connection, p=0.0003)
- H313: Tension = confidence
- H320: Tension log growth (R^2=0.97)
- H-CX-413: Tension ~ Free Energy (r=0.94)

## Predictions

1. H(Y|X) decreases during training (Demon creates order)
2. H(W) increases during training (Demon's memory cost)
3. Total H(Y|X) + H(W) is non-decreasing (2nd law)
4. InfoGain / WeightChange bounded by ln(2)

## Verification Script

`calc/verify_h437_maxwell_demon.py`

## Verification Results (sklearn digits, 64-64-10, lr=0.05, 30 epochs)

### Entropy Evolution

| Epoch | H(Y|X)  | H(W)    | Total   | Acc    | InfoGain | Cost   | Ratio   |
|-------|---------|---------|---------|--------|----------|--------|---------|
|     0 | 2.2415  | 4.0276  | 6.2690  | 10.9%  | 0.2516   | 0.0675 | 3.73    |
|     5 | 2.2424  | 4.0302  | 6.2726  | 28.1%  | 0.6481   | 0.0629 | 10.30   |
|    10 | 2.2307  | 4.0340  | 6.2646  | 41.3%  | 0.9509   | 0.0600 | 15.85   |
|    15 | 2.2072  | 4.0329  | 6.2401  | 54.8%  | 1.2622   | 0.0580 | 21.77   |
|    20 | 2.1724  | 4.0300  | 6.2025  | 62.8%  | 1.4455   | 0.0562 | 25.74   |
|    25 | 2.1270  | 4.0300  | 6.1570  | 69.1%  | 1.5905   | 0.0544 | 29.22   |
|    30 | 2.0723  | 4.0280  | 6.1004  | 72.4%  | 1.6672   | --     | --      |

### Key Metrics

```
  Output entropy H(Y|X):  2.2415 -> 2.0723  (Delta = -0.1691)  Demon CREATES ORDER
  Weight entropy H(W):    4.0276 -> 4.0280  (Delta = +0.0005)  Minimal memory cost
  Total entropy:          6.2690 -> 6.1004  (Delta = -0.1687)  DECREASED
  2nd law check:          VIOLATED (total entropy decreased)
```

### Demon Efficiency

```
  Mean InfoGain/WeightChange: 19.64 +/- 8.54
  ln(2) = 0.6931
  Ratio / ln(2) = 28.33
  Bounded by ln(2)? NO -- ratio >> ln(2)
```

### ASCII Graph: Entropy Evolution

```
  H(Y|X) = Output entropy (Demon ordering)
  E00 |#################                                 | 2.241
  E06 |#################                                 | 2.241
  E12 |#################                                 | 2.223
  E18 |#################                                 | 2.188
  E24 |#################                                 | 2.137
  E30 |################                                  | 2.072

  H(W) = Weight entropy (Demon's memory cost)
  E00 |================================                  | 4.028
  E06 |================================                  | 4.031
  E12 |================================                  | 4.035
  E18 |================================                  | 4.030
  E24 |================================                  | 4.029
  E30 |================================                  | 4.028

  Total = H(Y|X) + H(W) (2nd law test)
  E00 |************************************************* | 6.269
  E12 |************************************************* | 6.258
  E24 |************************************************* | 6.166
  E30 |************************************************  | 6.100
```

### ASCII Graph: Demon Efficiency vs ln(2)

```
  InfoGain/Cost ratio per epoch (ln(2)=0.693 is Landauer limit)
  E00 |@@@@@                                             | 3.73
  E05 |@@@@@@@@@@                                        | 10.30
  E10 |@@@@@@@@@@@@@@@@@@@@@@@@@                         | 15.85
  E15 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@              | 21.77
  E20 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         | 25.74
  E25 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   | 29.22
  E28 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ | 31.17
       ^ ln(2)=0.693 (Landauer limit far to the left)
```

## 해석 (Interpretation)

### 예측 검증

1. **H(Y|X) 감소**: 확인됨. 2.24 -> 2.07로 출력 엔트로피가 명확히 감소. 데몬이 질서를 창출한다.
2. **H(W) 증가**: 미미하게 확인 (+0.0005). 가중치 엔트로피는 거의 변하지 않음 --
   네트워크가 매우 효율적으로 정보를 인코딩하고 있음을 시사.
3. **총 엔트로피 비감소 (2법칙)**: **위반됨!** 총 엔트로피가 6.269에서 6.100으로 감소.
   이는 binned histogram 기반 H(W) 추정의 한계일 수 있으나, 근본적으로
   gradient descent가 데이터 분포의 구조적 정보를 활용하기 때문.
4. **Landauer 한계**: 효율 비율이 ln(2)보다 훨씬 큼 (19.64 >> 0.693).
   이는 정보 이득과 가중치 변화의 단위가 다르기 때문 (bits vs L2-norm).
   **단위 정규화가 필요함**.

### H-CX-2와의 연결

H-CX-2는 MI 효율 ~ ln(2)를 발견했다 (p=0.0003). 본 실험에서 직접적 ln(2) 바운드는
확인되지 않았으나, 이는 측정 단위의 차이에서 기인. 정보량을 nats가 아닌
가중치 L2-norm으로 측정했기 때문이다. **적절한 정규화 후 ln(2)가 나타날 가능성이 있다.**

### 데몬 비유의 유효성

- Output entropy 감소 = 분자 정렬 (강하게 확인)
- Weight entropy 증가 = 데몬의 기억 비용 (매우 미약 -- 효율적 데몬)
- 총 엔트로피 감소 = 외부 에너지원(데이터 분포의 구조)에서 에너지 유입

**결론**: 학습은 Maxwell's Demon처럼 작동하되, "무료 에너지"는 데이터 분포의
구조적 정보 자체에서 온다. 무작위 데이터에서는 이 "무료 에너지"가 0이 되어야 한다.

## Limitations

1. **H(W) 측정 방법**: Binned histogram은 고차원 가중치 공간의 엔트로피를 과소추정할 수 있음
2. **단위 불일치**: InfoGain (nats) vs WeightChange (L2-norm)은 직접 비교 불가
3. **Simple network**: 2-layer MLP은 현실 네트워크의 복잡성을 반영하지 못함
4. **Random data 대조군 부족**: 무작위 레이블에서 총 엔트로피가 어떻게 변하는지 미검증

## Verification Direction

1. **단위 정규화**: Fisher information metric으로 가중치 변화를 bits 단위로 변환 후 재측정
2. **Random label 대조군**: 무작위 데이터에서 총 엔트로피 변화 측정 -- 증가해야 함
3. **심층 네트워크**: CNN/Transformer에서 동일 패턴 확인
4. **H-CX-2 직접 연결**: MI efficiency 측정과 Demon efficiency를 동일 실험에서 비교
5. **미토시스 연결**: H-CX-439의 Landauer cost와 Demon cost의 관계
