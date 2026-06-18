# H-CX-444: Complete Graph K_6 and Neural Architecture
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


**Golden Zone Dependency: PARTIAL** (K_6 properties are pure math; neural bottleneck connection is model-dependent)

## Hypothesis

> K_6 (complete graph on 6 vertices) possesses unique combinatorial properties
> (Ramsey R(3,3)=6, genus=1, spectral gap=6). Neural networks with 6-node
> bottleneck layers exhibit special properties: optimal information compression,
> or metrics related to tau(6)=4, phi(6)=2, sigma(6)=12.

## Background

Complete graph K_n on n vertices has edges=C(n,2), chromatic number=n, and for K_6
specifically, the Ramsey number R(3,3)=6 guarantees a monochromatic triangle in any
2-coloring of edges. This is related to the Information Bottleneck principle: a
6-dimensional bottleneck might force "monochromatic" (coherent) information triangles.

Related hypotheses:
- H-090: Master formula = perfect number 6
- H-098: 6 is the only perfect number with proper divisor reciprocal sum = 1
- H-172: G*I = D*P conservation law

## Part 1: K_n Graph Properties (Pure Mathematics)

| n | Edges | chi | Genus | Aut | Spectral Gap |
|---|-------|-----|-------|-----|-------------|
|  2 |     1 |   2 |    0 |        2 |  2 |
|  3 |     3 |   3 |    0 |        6 |  3 |
|  4 |     6 |   4 |    0 |       24 |  4 |
|  5 |    10 |   5 |    1 |      120 |  5 |
|  6 |    15 |   6 |    1 |      720 |  6 |
|  7 |    21 |   7 |    1 |     5040 |  7 |
|  8 |    28 |   8 |    2 |    40320 |  8 |
|  9 |    36 |   9 |    3 |   362880 |  9 |
| 10 |    45 |  10 |    4 |  3628800 | 10 |
| 12 |    66 |  12 |    6 |479001600 | 12 |

K_6 unique properties:
- **Ramsey**: R(3,3) = 6 (smallest n where K_n guarantees monochromatic K_3)
- **Genus**: 1 (toroidal, not planar; shared with K_5 and K_7)
- **Edges**: 15 = C(6,2) = T(5) (5th triangular number)
- **Spectral gap**: 6 = the perfect number itself
- **Eigenvalues**: 5 (multiplicity 1), -1 (multiplicity 5)

## Part 2: Neural Bottleneck Experiment

Architecture: 64 -> 32 -> bn -> 32 -> 10, trained on sklearn digits (10 classes).
Each bottleneck size tested with 3 random seeds.

| BN | Accuracy | Compression | GradFlow | EffRank(in/out) | SVDratio |
|----|----------|-------------|----------|-----------------|----------|
|  2 |   0.910  |    32.0x    |  5821.8  |   2.00 / 1.96   |    1.1   |
|  3 |   0.932  |    21.3x    |  4146.3  |   2.92 / 2.94   |    1.8   |
|  4 |   0.945  |    16.0x    |  3499.7  |   3.89 / 3.86   |    1.9   |
|  5 |   0.956  |    12.8x    |  2807.8  |   4.88 / 4.91   |    1.8   |
|  6 |   0.952  |    10.7x    |  3392.5  |   5.28 / 4.71   |    8.5   |
|  7 |   0.962  |     9.1x    |  2752.3  |   6.59 / 6.74   |    3.2   |
|  8 |   0.960  |     8.0x    |  3174.8  |   7.46 / 7.64   |    3.7   |
|  9 |   0.963  |     7.1x    |  3097.5  |   8.58 / 8.45   |    2.8   |
| 10 |   0.961  |     6.4x    |  2936.4  |   8.93 / 8.90   |    5.1   |
| 12 |   0.966  |     5.3x    |  3090.7  |  10.50 / 10.88  |    5.6   |

## ASCII Graph: Bottleneck Size vs Accuracy

```
  bn= 2 |                                              0.910
  bn= 3 |==================                            0.932
  bn= 4 |============================                  0.945
  bn= 5 |====================================          0.956
  bn= 6 |=================================             0.952  <-- n=6
  bn= 7 |==========================================    0.962
  bn= 8 |========================================      0.960
  bn= 9 |==========================================    0.963
  bn=10 |=========================================     0.961
  bn=12 |=============================================  0.966
         0.910                                         0.966
```

## ASCII Graph: Bottleneck Size vs Efficiency (Acc x Compression)

```
  bn= 2 |=============================================  29.13  BEST
  bn= 3 |===========================                    19.89
  bn= 4 |==================                             15.13
  bn= 5 |=============                                  12.23
  bn= 6 |=========                                      10.15  <-- n=6
  bn= 7 |======                                          8.80
  bn= 8 |====                                            7.68
  bn= 9 |===                                             6.85
  bn=10 |=                                               6.15
  bn=12 |                                                5.15
         0                                               30
```

## n=6 Anomaly: SVD Ratio Spike

```
  SVD Ratio (sigma_1 / sigma_min) by bottleneck size:

  9 |        *
  8 |
  7 |
  6 |
  5 |                                *      *
  4 |
  3 |    *                  *   *
  2 |  *    * *                    *
  1 |*
    +--+--+--+--+--+--+--+--+--+--+
     2  3  4  5  6  7  8  9 10 12

  n=6 has SVDratio=8.5, anomalously high (next highest: 5.6 at n=12)
  This indicates one singular value dominates: information flows through
  a single "channel" in the 6-dim bottleneck.
```

## 해석 (Interpretation)

n=6 보틀넥은 정확도 순위에서 7위/10개로, **정확도 측면에서 특별하지 않음**. 그러나:

1. **SVD ratio 이상치**: n=6에서 SVDratio = 8.5로 다른 크기 대비 현저히 높음.
   이는 6차원 보틀넥에서 정보가 하나의 주요 방향으로 집중됨을 의미.

2. **Effective rank 감소**: eff_rank_out = 4.71 < 5.28 = eff_rank_in.
   입력 쪽보다 출력 쪽 effective rank가 더 낮음 = 정보 압축이 비대칭적.
   4.71 ≈ tau(6) + phi(6)/3? 이는 ad hoc이므로 주의.

3. **효율성(Acc x Compression)**: 보틀넥이 작을수록 효율적 (bn=2가 최고).
   이는 단순히 압축비가 지배하기 때문. n=6이 특별한 효율성을 보이지 않음.

4. **K_6 Ramsey 연결**: R(3,3)=6이 정보 "삼각형 보장"과 연결되는지는
   이 실험으로는 확인 불가. attention graph에서 검증 필요.

## Limitations

- sklearn digits (1797 samples, 10 classes)는 작은 데이터셋
- Architecture 고정 (32-bn-32). 다른 구조에서 결과 다를 수 있음
- 3 seed만 사용 (통계적 유의성 제한)
- SVD ratio spike가 seed-dependent일 가능성
- Information Bottleneck 이론적 최적점은 이 실험으로 계산 불가

## Verification Direction

1. **SVD ratio anomaly 재현**: 더 많은 seed (30+)로 n=6 SVD ratio spike 확인
2. **Mutual information** 직접 측정: I(X;T)와 I(T;Y)의 IB curve에서 n=6 위치
3. **Larger dataset** (CIFAR-10, MNIST)에서 반복
4. **Ramsey property**: 6-node bottleneck의 activation pattern에서
   monochromatic triangle 구조 탐색
5. **tau(6)=4 depth test**: 깊이 2,3,4,5,6으로 실험하여 최적 depth 확인

## Grade: Inconclusive (interesting SVD anomaly, no clear n=6 advantage)

n=6 bottleneck shows no accuracy advantage, but SVD ratio spike (8.5 vs mean ~3.4)
warrants further investigation. Pure math properties of K_6 confirmed.

---

*Verified: 2026-03-26 | Script: docs/hypotheses/verify_444.py*
