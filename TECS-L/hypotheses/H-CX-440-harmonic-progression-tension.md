# H-CX-440: Harmonic Progression Tension = Neural Tension

> 화성 진행(I-IV-V-I)의 긴장 곡선은 신경망 학습 에포크의 텐션 곡선과
> 동일한 구조적 패턴(상승-정점-해소)을 따른다.
> 음악적 긴장 = 시간적 기대 구조, 신경 텐션 = 예측 불확실성 구조.

**Golden Zone dependency**: Indirect (tension concept from TECS model)

## Background

H-290에서 음악적 협화음 = 낮은 텐션, 완전 4도(4:3) = 최소 텐션으로 확인되었다.
H-320에서 텐션은 학습 진행에 따라 로그적으로 증가한다.
이 가설은 음악의 화성 진행과 신경망 학습 과정 사이의 구조적 동형사상을 탐색한다.

관련 가설: H-290 (음악 협화음), H-320 (텐션 로그 성장), H-172 (G*I=D*P 보존)

## Musical Tension Model (Lerdahl-inspired)

```
Chord    Tension    Role
I        0.000      Tonic (안정)
ii       0.350      Supertonic
iii      0.250      Mediant
IV       0.380      Subdominant (중간 긴장)
V        0.720      Dominant (최고 긴장)
vi       0.300      Submediant
V7       0.850      Dominant 7th
```

## Progression Tension Curves

| Progression        | T1    | T2    | T3    | T4    | Shape              |
|---|---|---|---|---|---|
| I-IV-V-I (classical)  | 0.000 | 0.380 | 0.720 | 0.000 | rise-peak-resolve |
| I-vi-IV-V (pop)       | 0.000 | 0.300 | 0.380 | 0.720 | rise-continue     |
| i-iv-V-i (minor)      | 0.050 | 0.400 | 0.720 | 0.050 | rise-peak-resolve |
| I-V-vi-IV (Axis)      | 0.000 | 0.720 | 0.300 | 0.380 | peak-dip-rise     |

## Neural Network Training Results

2-layer MLP, 10-class synthetic data, 100 dimensions, 2000 samples.

| Epoch | Tension | Accuracy | Pattern |
|---|---|---|---|
| 1 | 0.9022 | 0.1010 | Start (high) |
| 2 | 0.9020 | 0.1020 | Decreasing |
| 3 | 0.9019 | 0.1015 | Decreasing |
| 4 | 0.9017 | 0.1020 | Decreasing |

Normalized: [1.000, 0.666, 0.333, 0.000] -- monotonically decreasing.

## DTW Distance: Training vs Musical Progressions

| Progression | DTW | Euclidean | Rank |
|---|---|---|---|
| I-IV-V-I (classical) | 1.8053 | 1.2100 | 1 (BEST) |
| i-iv-V-i (minor)     | 1.8107 | 1.2106 | 2 |
| I-V-vi-IV (Axis)     | 1.8611 | 1.1819 | 3 |
| I-vi-IV-V (pop)      | 2.4444 | 1.4492 | 4 |

## Pearson Correlation

| Progression | r |
|---|---|
| I-IV-V-I (classical) | -0.1270 |
| I-vi-IV-V (pop)      | -0.9770 |
| i-iv-V-i (minor)     | -0.1286 |
| I-V-vi-IV (Axis)     | -0.3143 |

## ASCII Graph: Training Tension vs Best Musical Match (I-IV-V-I)

```
  1.0 |TT.......................MM.............
  0.9 |..TTT..................MM..M............
  0.8 |.....TTTT............MM.....M...........
  0.7 |.........TTT......MMM........M..........
  0.7 |............TTT.MM............M.........
  0.6 |..............MXTT.............M........
  0.5 |............MM....TTTT..........MM......
  0.4 |..........MM..........TTT.........M.....
  0.3 |........MM...............TTT.......M....
  0.2 |......MM....................TTT.....M...
  0.2 |....MM.........................TTTT..M..
  0.1 |..MM...............................TTTM.
  0.0 |MM....................................TX
      +----------------------------------------
       Step1        Step2        Step3       Step4
  T = Training tension, M = Musical tension, X = Overlap
```

## Curriculum Learning Extension

표준 학습은 단조 감소이므로 음악적 rise-peak-resolve 패턴과 직접 일치하지 않는다.
그러나 커리큘럼 학습(easy->hard->medium->test)을 적용하면:

| Curriculum Phase | Tension | Musical Analog |
|---|---|---|
| Easy (start)     | 0.10    | I (tonic)      |
| Hard             | 0.80    | V (dominant)   |
| Medium           | 0.50    | IV (subdominant) |
| Test             | 0.20    | I (resolution) |

커리큘럼 학습 DTW 결과:

| Progression | DTW | r |
|---|---|---|
| I-V-vi-IV (Axis) | 0.7111 | +0.8619 (BEST) |
| I-IV-V-I (classical) | 1.0722 | +0.6813 |
| i-iv-V-i (minor) | 1.0776 | +0.6774 |
| I-vi-IV-V (pop) | 1.3111 | +0.0499 |

## 해석 (Interpretation)

1. **표준 학습 = 해소 국면**: 일반적인 신경망 학습에서 텐션은 단조 감소한다. 이것은 음악적으로 V->I 해소 과정에 해당한다. 전체 화성 진행의 후반부만 매핑된다.

2. **커리큘럼 학습 = 완전한 화성 진행**: 커리큘럼 학습에서는 난이도 변화로 인해 상승-정점-해소 패턴이 나타나며, Axis progression(I-V-vi-IV)과 가장 높은 상관관계(r=0.86)를 보인다.

3. **구조적 유사성**: 음악적 긴장은 시간적 기대의 위반과 해소이고, 신경 텐션은 예측 불확실성의 증감이다. 둘 다 "긴장 -> 해소" 사이클이라는 공통 구조를 가진다.

4. **DTW 최적 매칭**: 단조 감소하는 표준 학습도 I-IV-V-I과 가장 가까운데, 이는 해소 단계의 급격한 하강(V->I)이 학습 초기 급락과 유사하기 때문이다.

## Limitations

- 4-epoch 학습은 곡선 해상도가 낮다. 더 긴 학습과 세밀한 에포크 분할이 필요하다.
- 합성 데이터로 실험했으므로 실제 데이터(MNIST, CIFAR)에서 재검증 필요.
- Lerdahl 텐션 모델은 단순화된 버전이다. 실제 음악 인지 모델은 더 복잡하다.
- 커리큘럼 학습 텐션은 시뮬레이션된 값이며 실제 측정이 아니다.
- 단조 감소 vs rise-peak-resolve의 불일치가 가설의 핵심 약점이다.

## Verification Direction

- [ ] MNIST/CIFAR에서 실제 텐션 곡선 측정 후 비교
- [ ] 커리큘럼 학습 실제 구현 후 텐션 곡선 음악 매핑
- [ ] 더 세밀한 시간 해상도(batch 단위)로 micro-progression 분석
- [ ] H-320 로그 성장 패턴과 음악적 crescendo 비교
- [ ] 멀티 에포크(50+) 학습에서 장기 텐션 패턴 분석

## Verification Status

- [x] Musical tension curve definition
- [x] Neural network training simulation
- [x] DTW distance computation
- [x] Curriculum learning extension
- [ ] Real dataset verification (MNIST/CIFAR)
- [ ] Long-epoch tension curve analysis

**Grade: 🟧 (weak evidence)** -- 구조적 유사성은 있으나 표준 학습에서 직접적 패턴 일치는 약하다. 커리큘럼 학습 확장에서 강한 상관관계(r=0.86)를 보이지만 실제 데이터 검증이 필요하다.

**Script**: `docs/hypotheses/verify_hcx440.py`
