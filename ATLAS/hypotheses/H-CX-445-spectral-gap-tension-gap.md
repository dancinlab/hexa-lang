# H-CX-445: Spectral Gap = Tension Gap
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


**Golden Zone Dependency: NO** (spectral theory and tension are independently defined)

## Hypothesis

> The spectral gap of neural network weight matrices (lambda_1 - lambda_2) correlates
> with the tension gap (max class tension - min class tension) across training epochs.
> This connects spectral theory of random matrices to the tension framework in TECS-L.

## Background

Spectral gap controls mixing time in Markov chains: larger gap = faster convergence
to stationary distribution. In neural networks, the spectral gap of weight matrices
governs gradient flow and information propagation. If this correlates with tension
gap (the spread of per-class prediction difficulty), it would provide a theoretical
bridge between linear algebra and the tension framework.

Related hypotheses:
- H-172: G*I = D*P conservation law
- H-139: Golden Zone = edge of chaos
- H-CX-443: small-world topology (spectral gap also appears in graph theory)

## Method

1. Custom MLP (64-128-64-10) trained on sklearn digits for 50 epochs
2. Per-epoch tracking of:
   - Spectral gap per layer: SVD of weight matrix, gap = sigma_1 - sigma_2
   - Per-class tension: tension = (1 - max_prob + normalized_entropy) / 2
   - Tension gap = max(class_tension) - min(class_tension)
3. Pearson correlation across all 50 epochs

## Verification Results

### Correlation Matrix

| Pair | r | Strength |
|------|---|----------|
| Spectral Gap vs Tension Gap   | **+0.9712** | **STRONG** |
| Spectral Gap vs Mean Tension  |   -0.8698   |   STRONG   |
| Spectral Gap vs Accuracy      |   +0.8482   |   STRONG   |
| Tension Gap  vs Accuracy      |   +0.8616   |   STRONG   |

### Per-Layer Analysis

| Layer | r(Tension Gap) | r(Accuracy) | Role |
|-------|---------------|-------------|------|
| Layer 0 (input->hidden) | **+0.9315** | +0.7327 | Strongest correlator |
| Layer 1 (hidden->hidden) | +0.6788 | +0.7951 | Moderate |
| Layer 2 (hidden->output) | +0.0099 | -0.0232 | No correlation |

### Training Trajectory

```
  Epoch | Accuracy | Spec Gap Total | Tension Gap | Mean Tension
  ------|----------|---------------|-------------|-------------
     10 |   0.711  |     0.356     |    0.072    |    0.900
     20 |   0.858  |     0.460     |    0.268    |    0.726
     30 |   0.906  |     0.467     |    0.374    |    0.486
     40 |   0.908  |     0.467     |    0.327    |    0.342
     50 |   0.919  |     0.480     |    0.287    |    0.261
```

### Per-Class Tension (Final Epoch)

```
  Class | Tension | Bar                          | Note
  ------|---------|------------------------------|------
    0   |  0.176  | ======                       |
    1   |  0.293  | ==========                   |
    2   |  0.244  | ========                     |
    3   |  0.288  | ==========                   |
    4   |  0.177  | ======                       |
    5   |  0.272  | =========                    |
    6   |  0.145  | =====                        | EASIEST
    7   |  0.191  | =======                      |
    8   |  0.432  | ===============              | HARDEST
    9   |  0.419  | ==============               |

  Tension gap = 0.432 - 0.145 = 0.287
  Hardest: 8 (handwritten 8 has most variation)
  Easiest: 6 (consistent shape)
```

## ASCII Graph: Spectral Gap (S) and Tension Gap (T) Over Training

```
  S=0.48, T=0.37 |
                  |                             T                   S
                  |                         TTTT TTTTT T        SSSS
                  |                     SSXXSSSSSSSSSSXSXTSSSSSS
                  |                   SS T               STTT T T
                  |                  S  T                    T T  T
                  |                 S  T                         T TT
                  |                   T
                  |                S T
                  |                 T
                  |               ST
                  |
                  |              XT
                  |
                  |             X
                  |            T
                  |           TS
                  |         TTS
                  |        T S
                  |       T S
                  |XXXXXXXSS
  S=0.35, T=0.01 |--------------------------------------------------
                   1                                                50
                   S=Spectral Gap, T=Tension Gap, X=Overlap
```

## ASCII Scatter: Total Spectral Gap vs Tension Gap

```
  TG 0.37 |
          |                         *
          |                     **
          |                     *
          |                     *
          |                     ***
          |                      **
          |                     * *
          |
          |                    *
          |                  **
          |
          |               *
          |
          |             *
          |          *
          |
          |        *
          |      *
          |    *
          |
          |  *
          | *
          |*
          |*
          |**
  TG 0.01 |-------------------------
           SG=0.35         SG=0.48

  Pearson r = +0.9712  (p < 0.001)
```

## 해석 (Interpretation)

**핵심 발견: Spectral Gap과 Tension Gap 사이에 r = +0.97의 매우 강한 양의 상관관계가 존재한다.**

이 결과의 의미:

1. **Layer 0 (입력층)이 지배적**: r = +0.93으로 가장 강한 상관. 입력 데이터를
   처음 변환하는 층의 spectral 구조가 전체 tension 분포를 결정함.

2. **Layer 2 (출력층)은 무관**: r = +0.01로 상관 없음. 출력층은 이미
   "결정된" 표현을 분류할 뿐, tension 구조에 기여하지 않음.

3. **Markov mixing time 연결**: Spectral gap이 증가하면 mixing이 빨라져야 하는데,
   tension gap도 동시에 증가. 이는 학습 초기에는 모든 클래스가 비슷하게 어렵고
   (low tension gap), 학습이 진행되면서 "쉬운 클래스와 어려운 클래스"가 분화됨을
   의미. Spectral gap 증가 = 네트워크가 더 강한 특징을 학습 = 클래스 간 차이 증가.

4. **양의 상관**: 처음에는 "spectral gap 증가 -> tension gap 감소"를 예상했으나,
   실제로는 양의 상관. 네트워크가 정보를 더 잘 분리할수록(spectral gap 증가),
   클래스 간 tension 차이도 증가함. 이는 직관적: 잘 학습된 네트워크는
   쉬운 것은 매우 쉽게, 어려운 것은 여전히 어렵게 처리.

5. **Digit 8이 가장 어려움**: Tension = 0.432. 8은 다른 숫자와 시각적으로 혼동
   (3, 5, 9와 부분 유사). **Digit 6이 가장 쉬움**: Tension = 0.145.
   완전수 6이 가장 쉬운 숫자라는 것은 우연의 일치이나 주목할 만함.

## Theoretical Connection

```
  Spectral gap (linear algebra)     Tension gap (TECS-L framework)
        |                                    |
        v                                    v
  lambda_1 - lambda_2              max_c(T_c) - min_c(T_c)
        |                                    |
        +--- r = +0.97 ---+                  |
                           |                  |
                     Both measure:            |
                "separation strength"         |
                of the representation         |
                                              |
  Markov mixing time ~ 1/gap    Convergence difficulty ~ tension
```

## Limitations

- sklearn digits만 사용 (1797 samples). MNIST/CIFAR에서 재현 필요
- Custom MLP (Xavier init, manual backprop) 사용. PyTorch MLP과 비교 필요
- 50 epoch만 추적. 더 긴 학습에서 상관 유지되는지 확인 필요
- Tension 정의가 (1 - max_prob + entropy) / 2로 특정. 다른 정의에서도 유효한지
- Causal direction 불분명: spectral gap이 tension gap을 결정하는가, 아니면 공통 원인?
- Strong Law of Small Numbers 주의: 50 data points로 r=0.97은 인상적이나
  epoch 간 자기상관(autocorrelation) 때문에 effective sample size가 더 작을 수 있음

## Verification Direction

1. **MNIST/CIFAR-10**에서 재현 (더 큰 네트워크, 더 긴 학습)
2. **Epoch autocorrelation 보정**: first-difference correlation 계산
3. **Causal test**: spectral gap을 인위적으로 조작 (spectral normalization)하여
   tension gap 변화 관찰
4. **PH (persistent homology) H0 count**와 spectral gap 비교
5. **Layer-wise 분석 심화**: 어떤 singular value가 tension에 가장 기여하는지
6. **Cross-dataset**: spectral gap ~ tension gap 관계가 dataset-independent인지

## Grade: Strong Evidence (r = +0.97, p < 0.001)

Spectral gap and tension gap show very strong positive correlation across training.
Layer 0 dominates the relationship. This is a promising bridge between spectral
theory and the tension framework, but causal direction and generalization remain
to be established.

---

*Verified: 2026-03-26 | Script: docs/hypotheses/verify_445.py*
