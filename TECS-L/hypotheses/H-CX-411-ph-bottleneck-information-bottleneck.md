# Hypothesis H-CX-411: PH Bottleneck = Information Bottleneck
**n6 Grade: 🟩 EXACT** (auto-graded, 13 unique n=6 constants)


## Hypothesis

> H0 decrease = compression, beta1 generation = structuring.
> The Information Bottleneck's compression-to-prediction transition
> synchronizes with PH changes: MI(X;T) decrease correlates with H0 decrease.

## Background / Context

Information Bottleneck (IB) 이론 (Tishby et al., 2015)은 심층 학습을 두 단계로 설명한다:
1. **Fitting phase**: MI(T;Y) 증가 (표현이 label 정보를 획득)
2. **Compression phase**: MI(X;T) 감소 (불필요한 입력 정보 제거)

PH에서 H0 (connected components) 감소는 가중치 공간에서 클러스터가 병합되는
것을 의미하며, 이는 정보 압축과 구조적으로 동일할 수 있다.

관련 가설:
- H-CX-410: PH barcode = memory fingerprint (null result)
- H-CX-90: Epoch-1 phase transition
- H-CX-172: G*I = D*P conservation law

## Experimental Design

```
  Network: 784 → 64 (ReLU) → 10 (Softmax)
  Data: MNIST 3000 train / 500 test, 10 epochs

  Measurements per epoch:
    1. MI(X;T): Mutual information between input and hidden (binned, 20 bins)
    2. MI(T;Y): Mutual information between hidden and label (binned)
    3. H0: Connected components from W1 distance matrix (auto-threshold)
    4. Test accuracy
```

## Verification Results

### Training Progression with MI and PH

| Epoch | Loss   | Acc    | MI(X;T) | MI(T;Y) | H0_mean | H0_sum |
|-------|--------|--------|---------|---------|---------|--------|
| 0     | 1.6582 | 0.0940 | 0.6318  | 0.3240  | 3.50    | 35     |
| 1     | 0.8586 | 0.7080 | 0.9860  | 0.3601  | 3.50    | 35     |
| 2     | 0.6196 | 0.7960 | 1.1094  | 0.3608  | 3.50    | 35     |
| 3     | 0.5158 | 0.8320 | 1.0522  | 0.3453  | 3.50    | 35     |
| 4     | 0.4547 | 0.8520 | 1.0819  | 0.3703  | 3.50    | 35     |
| 5     | 0.4136 | 0.8520 | 1.1116  | 0.3743  | 3.50    | 35     |
| 6     | 0.3827 | 0.8880 | 1.0543  | 0.3577  | 3.50    | 35     |
| 7     | 0.3586 | 0.8700 | 1.0394  | 0.3488  | 3.50    | 35     |
| 8     | 0.3428 | 0.8880 | 1.0796  | 0.3832  | 3.50    | 35     |
| 9     | 0.3222 | 0.8940 | 1.0310  | 0.3657  | 3.50    | 35     |
| 10    | --     | 0.8940 | 1.0131  | 0.3674  | 3.50    | 35     |

### Correlation Analysis

```
  Pearson Correlations (level):
    MI(X;T) vs Accuracy: r = +0.9457    *** Strong positive
    MI(T;Y) vs Accuracy: r = +0.7580    **  Moderate positive
    MI(X;T) vs H0_mean:  r = NaN        (H0 constant)
    MI(T;Y) vs H0_mean:  r = NaN        (H0 constant)
    H0_mean vs Accuracy: r = NaN        (H0 constant)
```

### Information Bottleneck Phase Detection

```
  Fitting epochs  (dMI(T;Y) > 0):    6/10  (60%)
  Compression epochs (dMI(X;T) < 0): 5/10  (50%)
  H0 decrease epochs:                0/10  (0%)
  Co-occurrence (compress + H0 drop): 0/10 (0%)
```

### H0 Barcode at Different Thresholds

```
  Threshold:  0.50  0.52  0.54  0.55  0.57  0.58  0.60  0.62  0.64  0.66
  Epoch 0:      16     9     3     1     1     1     1     1     1     1
  Final:        16     9     3     1     1     1     1     1     1     1
  Delta:        +0    +0    +0    +0    +0    +0    +0    +0    +0    +0
```

## ASCII Graph: MI(X;T), MI(T;Y), H0 (normalized) Over Epochs

```
  Normalized value (0-1 scale)
  1.0 |       X        X        Y
  0.9 |          X  X  Y  X  X  X
  0.8 |             Y  Y     X     X  X
  0.7 |    X                       Y  Y
  0.6 |    Y  Y           Y
  0.5 | H──H──H──H──H──H──H──H──H──H──H  ← H0 constant!
  0.4 |          Y           Y
  0.3 |          Y
  0.2 |
  0.1 |
  0.0 | *
      +───────────────────────────────────
       ep0  1   2   3   4   5   6   7   8   9  10

  X = MI(X;T)  Y = MI(T;Y)  H = H0_mean  * = X+Y overlap
```

## ASCII Graph: IB Phase Diagram

```
  MI(T;Y)
  0.39 |                          8
       |              4     5
  0.37 |
       |    1                   9  10
  0.36 |         2
       |                   6
  0.35 |              3         7
       |
  0.33 |
       |
  0.32 | 0
       +──────────────────────────────
       0.6  0.7  0.8  0.9  1.0  1.1  1.2
                    MI(X;T)

  Numbers = epoch. Path: 0→1 = rapid fitting (MI(X;T) jump)
  Epochs 2-10: oscillation, no clear compression phase
```

## Key Findings

```
  1. MI(X;T) vs Accuracy: r = +0.9457 (매우 강한 양의 상관)
  2. MI(T;Y) vs Accuracy: r = +0.7580 (중간 양의 상관)
  3. H0 topology: 완전 불변 (모든 epoch, 모든 threshold에서 동일)
  4. IB compression phase: MI(X;T) 감소 epoch 50% — 부분적 존재
  5. PH-IB 동기화: 불가 (H0 변화 없음)
```

## Interpretation (해석)

**MI와 PH는 독립적인 측정이다 (이 scale에서).**

1. **IB fitting은 확인됨**: epoch 0→1에서 MI(X;T)가 0.63→0.99로 56% 급증하며,
   이는 H-CX-90의 epoch-1 phase transition과 일치한다. 네트워크가 첫 epoch에서
   입력 정보를 급격히 흡수한다.

2. **IB compression은 약하게 존재**: epoch 2 이후 MI(X;T)가 진동하며,
   Shwartz-Ziv & Tishby (2017)의 명확한 compression phase와는 다르다.
   이는 소규모 네트워크와 짧은 학습 때문일 수 있다.

3. **H0는 topology, MI는 geometry**: H0는 가중치 공간의 거시적 연결 구조를
   측정하고, MI는 활성화의 정보량을 측정한다. 이 둘은 서로 다른 수준의
   표현을 포착하며, H0의 불변성은 학습이 위상을 바꾸지 않고
   기하학만 변형함을 시사한다.

4. **MI(X;T)가 accuracy의 최선의 예측자**: r=0.95로, hidden representation이
   입력 정보를 얼마나 보존하는지가 성능을 결정한다는 직관을 확인한다.

## Limitations (한계)

- Binned MI estimation은 bin 수에 민감 (20 bins 사용)
- 소형 네트워크 (64 hidden) — 대규모에서는 IB compression이 더 명확할 수 있음
- H0만 측정 — H1 (loops)이 IB와 더 관련될 수 있음
- 단일 실행 — 통계적 유의성을 위해 반복 실험 필요
- MNIST는 상대적으로 단순한 task

## Verification Direction (다음 단계)

1. **H1 (loops) 측정 추가**: Rips complex에서 H1 barcode 계산
2. **Activation space PH**: 가중치가 아닌 hidden activation의 PH 측정 → IB와의 연관성 기대
3. **대규모 실험**: 256+ hidden units, 50+ epochs로 compression phase 명확화
4. **KDE-based MI**: Binned estimation 대신 KDE로 MI 정밀도 향상
5. **Cross-hypothesis**: H-CX-412의 persistence statistics와 MI의 관계

## Status

- **Grade**: Partial — MI-accuracy 상관은 강하나, PH-MI 동기화는 미확인
- **MI(X;T) vs Acc r=0.95**: 강한 결과 (IB fitting phase 확인)
- **PH-IB synchronization**: null result (H0 불변)
- **Script**: `scripts/verify_h_cx_411.py`
